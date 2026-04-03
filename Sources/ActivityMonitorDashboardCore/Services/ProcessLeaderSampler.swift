import Foundation
import OSLog

public actor ProcessLeaderSampler {
    private let logger = Logger(subsystem: "ActivityMonitorDashboard", category: "ProcessLeaderSampler")
    private let commandRunner = CommandRunner()
    private var cachedCPULeader: ProcessLeader?
    private var cachedMemoryLeader: ProcessLeader?
    private var lastCPUMemoryRefreshDate: Date?
    private var cachedGPULeader: ProcessLeader?
    private var lastGPURefreshDate: Date?
    private var previousGPUTotals: [Int32: UInt64] = [:]
    private var lastGPUSampleDate: Date?

    public init() {}

    public func sampleCPUMemoryLeadersIfNeeded(
        at date: Date,
        minimumRefreshInterval: TimeInterval = 2
    ) async -> (cpu: ProcessLeader?, memory: ProcessLeader?) {
        if let lastCPUMemoryRefreshDate,
           date.timeIntervalSince(lastCPUMemoryRefreshDate) < minimumRefreshInterval
        {
            return (cachedCPULeader, cachedMemoryLeader)
        }

        async let cpuLeader = sampleCPULeader()
        async let memoryLeader = sampleMemoryLeader()

        let leaders = (
            cpu: await cpuLeader,
            memory: await memoryLeader
        )

        cachedCPULeader = leaders.cpu
        cachedMemoryLeader = leaders.memory
        lastCPUMemoryRefreshDate = date
        return leaders
    }

    public func sampleGPULeaderIfNeeded(
        at date: Date,
        overallUtilization: Double,
        minimumRefreshInterval: TimeInterval = 1
    ) async -> ProcessLeader? {
        if let lastGPURefreshDate,
           date.timeIntervalSince(lastGPURefreshDate) < minimumRefreshInterval
        {
            return cachedGPULeader
        }

        let leader = await sampleCurrentGPULeader(at: date, overallUtilization: overallUtilization)
        cachedGPULeader = leader
        lastGPURefreshDate = date
        return leader
    }

    private func sampleCPULeader() async -> ProcessLeader? {
        guard let output = await commandRunner.run(
            executable: "/usr/bin/top",
            arguments: ["-l", "2", "-n", "12", "-stats", "pid,command,cpu"]
        ) else {
            return nil
        }

        let tables = splitTopTables(from: output)

        guard let lastTable = tables.last else {
            return nil
        }

        let rows = parseTopRows(
            from: lastTable,
            pattern: #"^\s*(\d+)\s+(.+?)\s+([0-9]+(?:\.[0-9]+)?)\s*$"#
        )

        guard let row = rows.first else {
            return nil
        }

        return ProcessLeader(
            name: row.command,
            metricKind: .percent,
            numericValue: row.numericValue,
            displayValue: Self.percentString(from: row.numericValue)
        )
    }

    private func sampleMemoryLeader() async -> ProcessLeader? {
        guard let output = await commandRunner.run(
            executable: "/usr/bin/top",
            arguments: ["-l", "1", "-n", "12", "-o", "mem", "-stats", "pid,command,mem"]
        ) else {
            return nil
        }

        let tables = splitTopTables(from: output)

        guard let table = tables.last else {
            return nil
        }

        let rows = parseTopRows(
            from: table,
            pattern: #"^\s*(\d+)\s+(.+?)\s+(\S+)\s*$"#
        )

        guard let row = rows.first else {
            return nil
        }

        return ProcessLeader(
            name: row.command,
            metricKind: .bytes,
            numericValue: row.numericValue,
            displayValue: Self.formattedMemoryMetricDisplay(row.displayValue)
        )
    }

    private func sampleCurrentGPULeader(at date: Date, overallUtilization: Double) async -> ProcessLeader? {
        guard let output = await commandRunner.run(
            executable: "/usr/sbin/ioreg",
            arguments: ["-r", "-c", "IOAccelerator", "-l", "-w", "0"]
        ) else {
            logger.error("GPU leader sampling failed: ioreg did not return usable output")
            return nil
        }

        let snapshot = Self.parseGPURegistrySnapshot(from: output)
        let totalsByProcess = snapshot.processes
        logger.debug(
            "GPU snapshot parsed \(totalsByProcess.count) processes, lastSubmittedPID=\(snapshot.lastSubmittedPID ?? -1), overallUtilization=\(overallUtilization)"
        )

        let previousTotals = previousGPUTotals
        let previousDate = lastGPUSampleDate
        previousGPUTotals = totalsByProcess.mapValues(\.total)
        lastGPUSampleDate = date

        guard !totalsByProcess.isEmpty else {
            logger.warning("GPU snapshot contained no process usage entries")
            return nil
        }

        if let previousDate {
            let elapsedInterval = max(date.timeIntervalSince(previousDate), 0.001)
            let bestLeader = scaledGPULeader(
                from: totalsByProcess,
                previousTotals: previousTotals,
                elapsedInterval: elapsedInterval,
                overallUtilization: overallUtilization
            )

            if let bestLeader {
                logger.debug("GPU leader selected from deltas: \(bestLeader.name) \(bestLeader.displayValue)")
                return bestLeader
            }

            logger.debug("GPU leader delta calculation produced no winner; falling back to estimated or last-submission heuristics")
        } else {
            logger.debug("GPU leader baseline established; using estimated winner until a delta sample is available")
        }

        if let estimatedLeader = estimatedGPULeader(
            from: Array(totalsByProcess.values),
            overallUtilization: overallUtilization
        ) {
            logger.debug("GPU leader selected from estimated activity: \(estimatedLeader.name) \(estimatedLeader.displayValue)")
            return estimatedLeader
        }

        guard let lastSubmittedPID = snapshot.lastSubmittedPID else {
            logger.warning("GPU leader fallback failed: no lastSubmittedPID available")
            return nil
        }

        let fallbackName: String
        if let knownName = totalsByProcess[lastSubmittedPID]?.name {
            fallbackName = knownName
        } else if let sampledName = await sampleProcessName(for: lastSubmittedPID) {
            fallbackName = sampledName
        } else {
            fallbackName = "PID \(lastSubmittedPID)"
        }
        let fallbackPercent = max(overallUtilization * 100, 0)
        logger.debug("GPU leader selected from lastSubmittedPID fallback: \(fallbackName) \(fallbackPercent)")
        return ProcessLeader(
            name: fallbackName,
            metricKind: .percent,
            numericValue: fallbackPercent,
            displayValue: Self.percentString(from: fallbackPercent)
        )
    }

    private func scaledGPULeader(
        from processesByPID: [Int32: GPUProcessMetrics],
        previousTotals: [Int32: UInt64],
        elapsedInterval: TimeInterval,
        overallUtilization: Double
    ) -> ProcessLeader? {
        let rawPercents = processesByPID.compactMapValues { process -> Double? in
            guard let previousTotal = previousTotals[process.pid],
                  process.total >= previousTotal
            else {
                return nil
            }

            let delta = process.total - previousTotal
            guard delta > 0 else {
                return nil
            }

            return (Double(delta) / elapsedInterval) / 10_000_000
        }

        guard !rawPercents.isEmpty else {
            return nil
        }

        let totalRawPercent = rawPercents.values.reduce(0, +)
        let targetSystemPercent = overallUtilization * 100
        let scaleFactor: Double

        if totalRawPercent > 0.01, targetSystemPercent > 0.01 {
            scaleFactor = targetSystemPercent / totalRawPercent
        } else {
            scaleFactor = 1
        }

        guard let best = rawPercents.max(by: { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key > rhs.key
            }

            return lhs.value < rhs.value
        }),
        let process = processesByPID[best.key]
        else {
            return nil
        }

        let scaledPercent = max(best.value * scaleFactor, 0)

        return ProcessLeader(
            name: process.name,
            metricKind: .percent,
            numericValue: scaledPercent,
            displayValue: Self.percentString(from: scaledPercent)
        )
    }

    private func estimatedGPULeader(
        from processes: [GPUProcessMetrics],
        overallUtilization: Double
    ) -> ProcessLeader? {
        let activeProcesses = processes.filter {
            $0.lastSubmittedTime > 0 || $0.total > 0
        }

        guard let latestSubmission = activeProcesses.map(\.lastSubmittedTime).max(),
              latestSubmission > 0
        else {
            return nil
        }

        let recentWindow: UInt64 = 2_000_000_000
        let recentProcesses = activeProcesses.filter {
            latestSubmission >= $0.lastSubmittedTime &&
            latestSubmission - $0.lastSubmittedTime <= recentWindow
        }

        let candidates = recentProcesses.isEmpty ? activeProcesses : recentProcesses

        let scoredCandidates = candidates.map { process in
            let age = latestSubmission >= process.lastSubmittedTime
                ? latestSubmission - process.lastSubmittedTime
                : 0
            let recency = max(0, 1 - (Double(age) / Double(recentWindow)))
            let score = max(0.01, recency) * Double(max(process.activeUsageEntryCount, 1))
            return (process: process, score: score)
        }

        guard let leader = scoredCandidates.max(by: { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.process.total < rhs.process.total
            }

            return lhs.score < rhs.score
        }) else {
            return nil
        }

        let totalScore = scoredCandidates.reduce(0) { $0 + $1.score }
        let normalizedShare = totalScore > 0 ? leader.score / totalScore : 1
        let estimatedPercent = max(0, overallUtilization * normalizedShare * 100)

        return ProcessLeader(
            name: leader.process.name,
            metricKind: .percent,
            numericValue: estimatedPercent,
            displayValue: Self.percentString(from: estimatedPercent)
        )
    }

    private func splitTopTables(from output: String) -> [String] {
        let sections = output.components(separatedBy: "\nPID    COMMAND")

        guard sections.count > 1 else {
            return []
        }

        return sections.dropFirst().map { "PID    COMMAND" + $0 }
    }

    private func parseTopRows(from table: String, pattern: String) -> [ParsedTopRow] {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])

        return table
            .split(separator: "\n")
            .dropFirst()
            .compactMap { line in
                guard let regex,
                      let match = regex.firstMatch(
                        in: String(line),
                        options: [],
                        range: NSRange(location: 0, length: line.utf16.count)
                      ),
                      match.numberOfRanges >= 4
                else {
                    return nil
                }

                let lineString = String(line)
                let pid = nsSubstring(match.range(at: 1), in: lineString)
                let command = nsSubstring(match.range(at: 2), in: lineString)
                let metric = nsSubstring(match.range(at: 3), in: lineString)

                return ParsedTopRow(
                    pid: Int32(pid) ?? 0,
                    command: command.trimmingCharacters(in: .whitespaces),
                    numericValue: parseNumericMetric(metric),
                    displayValue: cleanedMetricDisplay(metric)
                )
            }
            .filter { $0.pid > 0 }
    }

    private func parseNumericMetric(_ metric: String) -> Double {
        let cleaned = metric
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "+- "))

        if let direct = Double(cleaned) {
            return direct
        }

        let suffix = cleaned.last?.uppercased() ?? ""
        let numberPart = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "+-KMGTP"))
        let baseValue = Double(numberPart) ?? 0

        let multiplier: Double

        switch suffix {
        case "K":
            multiplier = 1_024
        case "M":
            multiplier = 1_048_576
        case "G":
            multiplier = 1_073_741_824
        case "T":
            multiplier = 1_099_511_627_776
        case "P":
            multiplier = 1_125_899_906_842_624
        default:
            multiplier = 1
        }

        return baseValue * multiplier
    }

    private func cleanedMetricDisplay(_ metric: String) -> String {
        metric.trimmingCharacters(in: CharacterSet(charactersIn: "+- "))
    }

    private func parseCreator(_ creator: String) -> (pid: Int32, name: String)? {
        let pattern = #"pid\s+(\d+),\s+(.+)$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: creator.utf16.count)

        guard let regex,
              let match = regex.firstMatch(in: creator, options: [], range: range)
        else {
            return nil
        }

        let pidString = nsSubstring(match.range(at: 1), in: creator)
        let name = nsSubstring(match.range(at: 2), in: creator)
        return (Int32(pidString) ?? 0, name)
    }

    private func sampleProcessName(for pid: Int32) async -> String? {
        guard let output = await commandRunner.run(
            executable: "/bin/ps",
            arguments: ["-p", String(pid), "-o", "comm="]
        ) else {
            return nil
        }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: trimmed).lastPathComponent
    }

    private func nsSubstring(_ range: NSRange, in string: String) -> String {
        guard let swiftRange = Range(range, in: string) else {
            return ""
        }

        return String(string[swiftRange])
    }

    private static func percentString(from percent: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = percent >= 100 ? 0 : 1
        formatter.minimumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: percent)) ?? "0"
        return "\(formatted)%"
    }

    static func formattedMemoryMetricDisplay(_ metric: String) -> String {
        let cleaned = metric
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "+- "))

        guard let suffix = cleaned.last?.uppercased(),
              let rawValue = Double(cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "+-KMGTP")))
        else {
            return cleaned
        }

        let megabytes: Double

        switch suffix {
        case "K":
            megabytes = rawValue / 1_000
        case "M":
            megabytes = rawValue
        case "G":
            megabytes = rawValue * 1_000
        case "T":
            megabytes = rawValue * 1_000_000
        case "P":
            megabytes = rawValue * 1_000_000_000
        default:
            return cleaned
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1

        if megabytes >= 1_000 {
            let gigabytes = megabytes / 1_000
            let formatted = formatter.string(from: NSNumber(value: gigabytes)) ?? "0.0"
            return "\(formatted) GB"
        }

        let formatted = formatter.string(from: NSNumber(value: megabytes)) ?? "0.0"
        return "\(formatted) MB"
    }

    static func parseGPURegistrySnapshot(from output: String) -> GPURegistrySnapshot {
        var lastSubmittedPID: Int32?
        var processesByPID: [Int32: GPUProcessMetrics] = [:]
        var currentCreator: (pid: Int32, name: String)?
        var currentUsages: [GPUUsageEntry] = []

        func flushCurrentClient() {
            guard let currentCreator else {
                currentUsages = []
                return
            }

            let existing = processesByPID[currentCreator.pid] ?? GPUProcessMetrics(
                pid: currentCreator.pid,
                name: currentCreator.name
            )

            let usageTotal = currentUsages.reduce(into: existing) { partial, entry in
                partial.total += entry.accumulatedGPUTime
                partial.lastSubmittedTime = max(partial.lastSubmittedTime, entry.lastSubmittedTime)

                if entry.lastSubmittedTime > 0 || entry.accumulatedGPUTime > 0 {
                    partial.activeUsageEntryCount += 1
                }
            }

            processesByPID[currentCreator.pid] = usageTotal
            currentUsages = []
        }

        for line in output.split(separator: "\n").map(String.init) {
            if line.contains("AGXDeviceUserClient") {
                flushCurrentClient()
                currentCreator = nil
                continue
            }

            if line.contains("\"AGCInfo\""),
               let pid = firstMatch(in: line, pattern: #"fLastSubmissionPID\"=(\d+)"#)
            {
                lastSubmittedPID = Int32(pid)
            }

            if line.contains("\"IOUserClientCreator\""),
               let creator = firstMatch(in: line, pattern: #"\"IOUserClientCreator\"\s*=\s*\"([^\"]+)\""#)
            {
                currentCreator = parseCreatorStatic(creator)
            }

            if line.contains("\"AppUsage\"") {
                currentUsages = parseAppUsageEntries(from: line)
            }
        }

        flushCurrentClient()

        return GPURegistrySnapshot(
            lastSubmittedPID: lastSubmittedPID,
            processes: processesByPID
        )
    }

    private static func parseAppUsageEntries(from line: String) -> [GPUUsageEntry] {
        let usageRegex = try? NSRegularExpression(pattern: #"\{[^}]+\}"#)
        let range = NSRange(location: 0, length: line.utf16.count)
        let matches = usageRegex?.matches(in: line, options: [], range: range) ?? []

        return matches.compactMap { match in
            let entryString = substring(match.range, in: line)
            let lastSubmittedTime = UInt64(firstMatch(in: entryString, pattern: #"lastSubmittedTime\"=(\d+)"#) ?? "") ?? 0
            let accumulatedGPUTime = UInt64(firstMatch(in: entryString, pattern: #"accumulatedGPUTime\"=(\d+)"#) ?? "") ?? 0

            guard lastSubmittedTime > 0 || accumulatedGPUTime > 0 else {
                return nil
            }

            return GPUUsageEntry(
                lastSubmittedTime: lastSubmittedTime,
                accumulatedGPUTime: accumulatedGPUTime
            )
        }
    }

    private static func parseCreatorStatic(_ creator: String) -> (pid: Int32, name: String)? {
        let pattern = #"pid\s+(\d+),\s+(.+)$"#
        guard let pidString = firstMatch(in: creator, pattern: pattern, captureGroup: 1),
              let name = firstMatch(in: creator, pattern: pattern, captureGroup: 2)
        else {
            return nil
        }

        return (Int32(pidString) ?? 0, name)
    }

    private static func firstMatch(
        in string: String,
        pattern: String,
        captureGroup: Int = 1
    ) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: string.utf16.count)

        guard let regex,
              let match = regex.firstMatch(in: string, options: [], range: range),
              match.numberOfRanges > captureGroup
        else {
            return nil
        }

        return substring(match.range(at: captureGroup), in: string)
    }

    private static func substring(_ range: NSRange, in string: String) -> String {
        guard let swiftRange = Range(range, in: string) else {
            return ""
        }

        return String(string[swiftRange])
    }
}

private struct ParsedTopRow {
    let pid: Int32
    let command: String
    let numericValue: Double
    let displayValue: String
}

struct GPUProcessMetrics {
    let pid: Int32
    let name: String
    var total: UInt64
    var lastSubmittedTime: UInt64
    var activeUsageEntryCount: Int

    init(
        pid: Int32,
        name: String,
        total: UInt64 = 0,
        lastSubmittedTime: UInt64 = 0,
        activeUsageEntryCount: Int = 0
    ) {
        self.pid = pid
        self.name = name
        self.total = total
        self.lastSubmittedTime = lastSubmittedTime
        self.activeUsageEntryCount = activeUsageEntryCount
    }
}

struct GPURegistrySnapshot {
    let lastSubmittedPID: Int32?
    let processes: [Int32: GPUProcessMetrics]
}

private struct GPUUsageEntry {
    let lastSubmittedTime: UInt64
    let accumulatedGPUTime: UInt64
}

private actor CommandRunner {
    private let logger = Logger(subsystem: "ActivityMonitorDashboard", category: "CommandRunner")

    func run(executable: String, arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                let combinedOutput = Pipe()
                process.standardOutput = combinedOutput
                process.standardError = combinedOutput

                let commandDescription = ([executable] + arguments).joined(separator: " ")

                do {
                    try process.run()
                } catch {
                    self.logger.error("Failed to run command: \(commandDescription, privacy: .public). Error: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }

                let outputData = combinedOutput.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let output = String(decoding: outputData, as: UTF8.self)

                guard process.terminationStatus == 0 else {
                    if output.isEmpty {
                        self.logger.error("Command exited with status \(process.terminationStatus): \(commandDescription, privacy: .public)")
                    } else {
                        self.logger.error("Command exited with status \(process.terminationStatus): \(commandDescription, privacy: .public). Output: \(output, privacy: .public)")
                    }
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: output)
            }
        }
    }
}
