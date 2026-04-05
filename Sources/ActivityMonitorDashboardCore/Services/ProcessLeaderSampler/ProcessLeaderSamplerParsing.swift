import Foundation

extension ProcessLeaderSampler {
    private static let processSnapshotRegex = try! NSRegularExpression(
        pattern: #"^\s*(\d+)\s+([0-9]+(?:\.[0-9]+)?)\s+(\d+)\s+(.+?)\s*$"#,
        options: [.anchorsMatchLines]
    )
    private static let usageEntryRegex = try! NSRegularExpression(pattern: #"\{[^}]+\}"#)
    private static let lastSubmissionPIDRegex = try! NSRegularExpression(pattern: #"fLastSubmissionPID\"=(\d+)"#)
    private static let creatorRegex = try! NSRegularExpression(
        pattern: #"\"IOUserClientCreator\"\s*=\s*\"([^\"]+)\""#
    )
    private static let creatorPIDRegex = try! NSRegularExpression(pattern: #"pid\s+(\d+),\s+(.+)$"#)
    private static let lastSubmittedTimeRegex = try! NSRegularExpression(pattern: #"lastSubmittedTime\"=(\d+)"#)
    private static let accumulatedGPUTimeRegex = try! NSRegularExpression(pattern: #"accumulatedGPUTime\"=(\d+)"#)

    static func parseProcessSnapshot(from output: String) -> [ProcessSnapshotRow] {
        return output
            .split(separator: "\n")
            .compactMap { line in
                guard let match = processSnapshotRegex.firstMatch(
                        in: String(line),
                        options: [],
                        range: NSRange(location: 0, length: line.utf16.count)
                      ),
                      match.numberOfRanges >= 5
                else {
                    return nil
                }

                let lineString = String(line)
                let pid = Int32(substring(match.range(at: 1), in: lineString)) ?? 0
                let cpuPercent = Double(substring(match.range(at: 2), in: lineString)) ?? 0
                let residentKilobytes = UInt64(substring(match.range(at: 3), in: lineString)) ?? 0
                let rawCommand = substring(match.range(at: 4), in: lineString)
                    .trimmingCharacters(in: .whitespaces)
                let command = URL(fileURLWithPath: rawCommand).lastPathComponent

                guard pid > 0, !command.isEmpty else {
                    return nil
                }

                return ProcessSnapshotRow(
                    pid: pid,
                    command: command,
                    cpuPercent: max(0, cpuPercent),
                    residentKilobytes: residentKilobytes
                )
            }
    }

    static func percentString(from percent: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = percent >= 100 ? 0 : 1
        formatter.minimumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: percent)) ?? "0"
        return "\(formatted)%"
    }

    static func formattedMemoryKilobytesDisplay(_ kilobytes: UInt64) -> String {
        formattedMemoryMetricDisplay("\(kilobytes)K")
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
               let pid = firstMatch(in: line, regex: lastSubmissionPIDRegex)
            {
                lastSubmittedPID = Int32(pid)
            }

            if line.contains("\"IOUserClientCreator\""),
               let creator = firstMatch(in: line, regex: creatorRegex)
            {
                currentCreator = parseCreator(from: creator)
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
        let range = NSRange(location: 0, length: line.utf16.count)
        let matches = usageEntryRegex.matches(in: line, options: [], range: range)

        return matches.compactMap { match in
            let entryString = substring(match.range, in: line)
            let lastSubmittedTime = UInt64(firstMatch(in: entryString, regex: lastSubmittedTimeRegex) ?? "") ?? 0
            let accumulatedGPUTime = UInt64(firstMatch(in: entryString, regex: accumulatedGPUTimeRegex) ?? "") ?? 0

            guard lastSubmittedTime > 0 || accumulatedGPUTime > 0 else {
                return nil
            }

            return GPUUsageEntry(
                lastSubmittedTime: lastSubmittedTime,
                accumulatedGPUTime: accumulatedGPUTime
            )
        }
    }

    private static func parseCreator(from creator: String) -> (pid: Int32, name: String)? {
        guard let pidString = firstMatch(in: creator, regex: creatorPIDRegex, captureGroup: 1),
              let name = firstMatch(in: creator, regex: creatorPIDRegex, captureGroup: 2)
        else {
            return nil
        }

        return (Int32(pidString) ?? 0, name)
    }

    private static func firstMatch(
        in string: String,
        regex: NSRegularExpression,
        captureGroup: Int = 1
    ) -> String? {
        let range = NSRange(location: 0, length: string.utf16.count)

        guard let match = regex.firstMatch(in: string, options: [], range: range),
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
