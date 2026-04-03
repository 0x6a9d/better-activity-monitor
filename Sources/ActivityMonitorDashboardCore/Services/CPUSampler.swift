import Foundation
import Darwin

final class CPUSampler {
    private struct CPUClockTicks {
        let user: UInt64
        let system: UInt64
        let idle: UInt64
        let nice: UInt64
    }

    private var previousTicks: CPUClockTicks?

    func sample(powerWatts: Double? = nil) -> CPUSample {
        guard let currentTicks = readClockTicks() else {
            return CPUSample(userUsage: 0, systemUsage: 0, idleUsage: 1, powerWatts: powerWatts)
        }

        defer {
            previousTicks = currentTicks
        }

        guard let previousTicks else {
            return CPUSample(userUsage: 0, systemUsage: 0, idleUsage: 1, powerWatts: powerWatts)
        }

        let userDelta = currentTicks.user &- previousTicks.user
        let systemDelta = currentTicks.system &- previousTicks.system
        let idleDelta = currentTicks.idle &- previousTicks.idle
        let niceDelta = currentTicks.nice &- previousTicks.nice
        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta

        guard totalDelta > 0 else {
            return CPUSample(userUsage: 0, systemUsage: 0, idleUsage: 1, powerWatts: powerWatts)
        }

        let total = Double(totalDelta)
        let userUsage = Double(userDelta + niceDelta) / total
        let systemUsage = Double(systemDelta) / total
        let idleUsage = Double(idleDelta) / total

        return CPUSample(
            userUsage: userUsage,
            systemUsage: systemUsage,
            idleUsage: idleUsage,
            powerWatts: powerWatts
        )
    }

    private func readClockTicks() -> CPUClockTicks? {
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        var info = host_cpu_load_info_data_t()

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        return CPUClockTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }
}
