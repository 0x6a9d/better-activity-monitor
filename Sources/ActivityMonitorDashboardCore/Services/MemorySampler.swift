import Foundation
import Darwin

final class MemorySampler {
    private let physicalMemory = ProcessInfo.processInfo.physicalMemory

    func sample(powerWatts: Double? = nil) -> MemorySample {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemorySample(
                pressure: 0,
                level: .good,
                usedBytes: 0,
                cachedBytes: 0,
                compressedBytes: 0,
                freeBytes: physicalMemory,
                physicalMemoryBytes: physicalMemory,
                powerWatts: powerWatts
            )
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        let pageByteCount = UInt64(pageSize)
        let freeBytes = bytes(from: stats.free_count + stats.speculative_count, pageSize: pageByteCount)
        let purgeableBytes = bytes(from: stats.purgeable_count, pageSize: pageByteCount)
        let cachedBytes = bytes(from: stats.external_page_count + stats.inactive_count, pageSize: pageByteCount)
        let compressedBytes = bytes(from: stats.compressor_page_count, pageSize: pageByteCount)
        let wiredBytes = bytes(from: stats.wire_count, pageSize: pageByteCount)
        let activeBytes = bytes(from: stats.active_count, pageSize: pageByteCount)

        let totalBytes = max(physicalMemory, 1)
        let visibleCachedBytes = cachedBytes + purgeableBytes
        let usedBytes = min(totalBytes, activeBytes + wiredBytes + compressedBytes)

        let pressure = memoryPressureScore(
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            cachedBytes: visibleCachedBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes
        )
        let level = PressureLevel(
            normalizedValue: pressure,
            warningThreshold: 0.62,
            criticalThreshold: 0.84
        )

        return MemorySample(
            pressure: pressure,
            level: level,
            usedBytes: usedBytes,
            cachedBytes: visibleCachedBytes,
            compressedBytes: compressedBytes,
            freeBytes: freeBytes,
            physicalMemoryBytes: totalBytes,
            powerWatts: powerWatts
        )
    }

    private func memoryPressureScore(
        totalBytes: UInt64,
        freeBytes: UInt64,
        cachedBytes: UInt64,
        wiredBytes: UInt64,
        compressedBytes: UInt64
    ) -> Double {
        let total = Double(totalBytes)
        let availableRatio = Double(freeBytes + min(cachedBytes, totalBytes / 3)) / total
        let wiredRatio = Double(wiredBytes) / total
        let compressedRatio = Double(compressedBytes) / total

        let availabilityPressure = 1 - min(1, availableRatio / 0.35)
        let wiredPressure = min(1, wiredRatio / 0.32)
        let compressionPressure = min(1, compressedRatio / 0.16)

        return (
            availabilityPressure * 0.55 +
            wiredPressure * 0.20 +
            compressionPressure * 0.25
        ).clamped(to: 0...1)
    }

    private func bytes(from pageCount: UInt32, pageSize: UInt64) -> UInt64 {
        UInt64(pageCount) * pageSize
    }
}
