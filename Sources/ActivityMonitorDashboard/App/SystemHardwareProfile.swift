import Foundation
import ActivityMonitorDashboardCore

struct SystemHardwareProfile: Equatable {
    let chipName: String
    let totalCPUCores: Int?
    let efficiencyCoreCount: Int
    let performanceCoreCount: Int
    let superCoreCount: Int
    let gpuCoreCount: Int?
    let memoryDescription: String?

    static let unavailable = SystemHardwareProfile(
        chipName: "Apple Silicon",
        totalCPUCores: nil,
        efficiencyCoreCount: 0,
        performanceCoreCount: 0,
        superCoreCount: 0,
        gpuCoreCount: nil,
        memoryDescription: ByteCountFormatter.string(
            fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory),
            countStyle: .memory
        )
    )

    var chipDisplayName: String {
        chipName.isEmpty ? Self.unavailable.chipName : chipName
    }

    var cpuLoadTitleDetail: String? {
        totalCPUCores.map { "\($0) Cores" }
    }

    var cpuFrequencyTitleDetail: String? {
        let segments = cpuFrequencyTierSegments
        guard !segments.isEmpty else {
            return nil
        }

        return segments
            .map { "\($0.count)\($0.label.abbreviation)" }
            .joined(separator: " / ")
    }

    var gpuPressureTitleDetail: String? {
        gpuCoreCount.map { "\($0) Cores" }
    }

    var memoryPressureTitleDetail: String? {
        memoryDescription
    }

    private var cpuFrequencyTierSegments: [(label: CPUFrequencyTierLabel, count: Int)] {
        var segments: [(label: CPUFrequencyTierLabel, count: Int)] = []

        if efficiencyCoreCount > 0 {
            segments.append((.efficiency, efficiencyCoreCount))
        }

        if performanceCoreCount > 0 {
            segments.append((.performance, performanceCoreCount))
        }

        if superCoreCount > 0 {
            segments.append((.superTier, superCoreCount))
        }

        return segments
    }
}

@MainActor
final class SystemHardwareProfileStore: ObservableObject {
    @Published private(set) var profile: SystemHardwareProfile = .unavailable

    init() {
        Task {
            profile = await SystemHardwareProfileLoader.load()
        }
    }
}

enum SystemHardwareProfileLoader {
    static func load() async -> SystemHardwareProfile {
        await Task.detached(priority: .utility) {
            loadSynchronously()
        }
        .value
    }

    static func loadSynchronously() -> SystemHardwareProfile {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["-json", "SPHardwareDataType", "SPDisplaysDataType"]
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .unavailable
        }

        guard process.terminationStatus == 0 else {
            return .unavailable
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return parse(data: data) ?? .unavailable
    }

    static func parse(data: Data) -> SystemHardwareProfile? {
        guard !data.isEmpty else {
            return nil
        }

        let decoder = JSONDecoder()

        guard let payload = try? decoder.decode(SystemProfilerPayload.self, from: data),
              let hardware = payload.hardware.first
        else {
            return nil
        }

        let processorCounts = ProcessorCounts.parse(from: hardware.numberProcessors)
        let memoryDescription = hardware.physicalMemory?.trimmingCharacters(in: .whitespacesAndNewlines)
        let gpuCores = payload.displays
            .compactMap(\.coreCount)
            .first

        let performanceCoreCount: Int
        let superCoreCount: Int

        if processorCounts.mcpu > 0 {
            performanceCoreCount = processorCounts.mcpu
            superCoreCount = processorCounts.pcpu
        } else {
            performanceCoreCount = processorCounts.pcpu
            superCoreCount = 0
        }

        return SystemHardwareProfile(
            chipName: hardware.chipType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? SystemHardwareProfile.unavailable.chipName,
            totalCPUCores: processorCounts.total,
            efficiencyCoreCount: processorCounts.ecpu,
            performanceCoreCount: performanceCoreCount,
            superCoreCount: superCoreCount,
            gpuCoreCount: gpuCores,
            memoryDescription: memoryDescription ?? SystemHardwareProfile.unavailable.memoryDescription
        )
    }
}

private struct ProcessorCounts {
    let total: Int?
    let pcpu: Int
    let ecpu: Int
    let mcpu: Int

    static func parse(from rawValue: String?) -> ProcessorCounts {
        guard let rawValue,
              let payload = rawValue.split(separator: " ").last
        else {
            return ProcessorCounts(total: nil, pcpu: 0, ecpu: 0, mcpu: 0)
        }

        let parts = payload.split(separator: ":").compactMap { Int($0) }

        guard !parts.isEmpty else {
            return ProcessorCounts(total: nil, pcpu: 0, ecpu: 0, mcpu: 0)
        }

        return ProcessorCounts(
            total: parts[safe: 0],
            pcpu: parts[safe: 1] ?? 0,
            ecpu: parts[safe: 2] ?? 0,
            mcpu: parts[safe: 3] ?? 0
        )
    }
}

private struct SystemProfilerPayload: Decodable {
    let hardware: [HardwareEntry]
    let displays: [DisplayEntry]

    enum CodingKeys: String, CodingKey {
        case hardware = "SPHardwareDataType"
        case displays = "SPDisplaysDataType"
    }
}

private struct HardwareEntry: Decodable {
    let chipType: String?
    let numberProcessors: String?
    let physicalMemory: String?

    enum CodingKeys: String, CodingKey {
        case chipType = "chip_type"
        case numberProcessors = "number_processors"
        case physicalMemory = "physical_memory"
    }
}

private struct DisplayEntry: Decodable {
    let coreCountString: String?

    var coreCount: Int? {
        guard let coreCountString else {
            return nil
        }

        return Int(coreCountString)
    }

    enum CodingKeys: String, CodingKey {
        case coreCountString = "sppci_cores"
    }
}

private extension CPUFrequencyTierLabel {
    var abbreviation: String {
        switch self {
        case .efficiency:
            "E"
        case .performance:
            "P"
        case .superTier:
            "S"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
