import Foundation
import OSLog

public actor ProcessLeaderSampler {
    private static let minimumGPUUtilizationForLeaderSampling = 0.03

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

        let leaders = await sampleCPUMemoryLeaders()
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
        if overallUtilization < Self.minimumGPUUtilizationForLeaderSampling {
            cachedGPULeader = nil
            lastGPURefreshDate = date
            previousGPUTotals = [:]
            lastGPUSampleDate = nil
            return nil
        }

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

    private func sampleCPUMemoryLeaders() async -> (cpu: ProcessLeader?, memory: ProcessLeader?) {
        guard let output = await commandRunner.run(
            executable: "/bin/ps",
            arguments: ["-axo", "pid=,pcpu=,rss=,comm="]
        ) else {
            return (nil, nil)
        }

        let rows = Self.parseProcessSnapshot(from: output)
        guard !rows.isEmpty else {
            return (nil, nil)
        }

        let cpuLeader = rows.max(by: { lhs, rhs in
            if lhs.cpuPercent == rhs.cpuPercent {
                return lhs.pid > rhs.pid
            }

            return lhs.cpuPercent < rhs.cpuPercent
        }).map {
            ProcessLeader(
                name: $0.command,
                metricKind: .percent,
                numericValue: $0.cpuPercent,
                displayValue: Self.percentString(from: $0.cpuPercent)
            )
        }

        let memoryLeader = rows.max(by: { lhs, rhs in
            if lhs.residentKilobytes == rhs.residentKilobytes {
                return lhs.pid > rhs.pid
            }

            return lhs.residentKilobytes < rhs.residentKilobytes
        }).map {
            let residentBytes = $0.residentKilobytes * 1_024
            return ProcessLeader(
                name: $0.command,
                metricKind: .bytes,
                numericValue: Double(residentBytes),
                displayValue: Self.formattedMemoryKilobytesDisplay($0.residentKilobytes)
            )
        }

        return (cpuLeader, memoryLeader)
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
        let scaleFactor = (totalRawPercent > 0.01 && targetSystemPercent > 0.01)
            ? (targetSystemPercent / totalRawPercent)
            : 1.0

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
}
