import Foundation

struct ProcessSnapshotRow {
    let pid: Int32
    let command: String
    let cpuPercent: Double
    let residentKilobytes: UInt64
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

struct GPUUsageEntry {
    let lastSubmittedTime: UInt64
    let accumulatedGPUTime: UInt64
}
