import Foundation

public final class ThermalSampler {
    private var smcReader: AppleSMCReader?
    private var preferredSocTemperatureKeys: [String]?
    private var cpuTemperatureKeys: [String]?
    private var gpuTemperatureKeys: [String]?
    private var fallbackTemperatureGroups: [[String]]?

    public init() {}

    public func sample() -> ThermalSample {
        let thermalState = currentThermalState()

        guard let reader = openReader() else {
            return ThermalSample(
                thermalState: thermalState,
                socTemperatureCelsius: nil,
                cpuTemperatureCelsius: nil,
                gpuTemperatureCelsius: nil,
                fans: []
            )
        }

        let fans = sampleFans(with: reader)
        let temperatures = sampleTemperatures(with: reader)

        return ThermalSample(
            thermalState: thermalState,
            socTemperatureCelsius: temperatures.soc,
            cpuTemperatureCelsius: temperatures.cpu,
            gpuTemperatureCelsius: temperatures.gpu,
            fans: fans
        )
    }

    private func openReader() -> AppleSMCReader? {
        if smcReader == nil {
            smcReader = AppleSMCReader()
        }

        return smcReader
    }

    private func sampleTemperatures(with reader: AppleSMCReader) -> TemperatureSample {
        if preferredSocTemperatureKeys == nil ||
            cpuTemperatureKeys == nil ||
            gpuTemperatureKeys == nil ||
            fallbackTemperatureGroups == nil
        {
            discoverTemperatureKeys(with: reader)
        }

        let cpuTemperature = meanTemperature(for: cpuTemperatureKeys ?? [], with: reader)
        let gpuTemperature = meanTemperature(for: gpuTemperatureKeys ?? [], with: reader)
        let preferredSocTemperature = preferredSocTemperatureKeys?
            .compactMap { sanitizedTemperature(reader.value(for: $0)) }
            .first

        let familyMeans = fallbackTemperatureGroups?
            .compactMap { meanTemperature(for: $0, with: reader) } ?? []
        let fallbackSocTemperature = familyMeans.isEmpty
            ? nil
            : sanitizedTemperature(familyMeans.reduce(0, +) / Double(familyMeans.count))
        let derivedSocTemperature = [cpuTemperature, gpuTemperature]
            .compactMap { $0 }
            .max()

        return TemperatureSample(
            soc: derivedSocTemperature ?? preferredSocTemperature ?? fallbackSocTemperature,
            cpu: cpuTemperature,
            gpu: gpuTemperature
        )
    }

    private func currentThermalState() -> ThermalStateStatus {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            .normal
        case .fair:
            .fair
        case .serious:
            .serious
        case .critical:
            .critical
        @unknown default:
            .unknown
        }
    }

    private func discoverTemperatureKeys(with reader: AppleSMCReader) {
        let allKeys = Set(reader.allKeys())
        let preferredCandidates = ["TS0P", "TPMP", "TPSP", "TSWR", "TSVR", "TSXR"]
        preferredSocTemperatureKeys = preferredCandidates.filter { allKeys.contains($0) }
        cpuTemperatureKeys = temperatureKeys(withPrefixes: ["Tp", "Te"], from: allKeys)
        gpuTemperatureKeys = temperatureKeys(withPrefixes: ["Tg"], from: allKeys)

        let primaryFamilies = ["Tp", "Te", "Tg", "Tm"]
        let fallbackFamilies = ["Ta", "Tf"]
        let selectedFamilies = primaryFamilies
            .map { temperatureKeys(withPrefix: $0, from: allKeys) }
            .filter { !$0.isEmpty }

        if selectedFamilies.count >= 2 {
            fallbackTemperatureGroups = selectedFamilies
            return
        }

        fallbackTemperatureGroups = (primaryFamilies + fallbackFamilies)
            .map { temperatureKeys(withPrefix: $0, from: allKeys) }
            .filter { !$0.isEmpty }
    }

    private func temperatureKeys(withPrefixes prefixes: [String], from keys: Set<String>) -> [String] {
        prefixes
            .flatMap { temperatureKeys(withPrefix: $0, from: keys) }
            .sorted()
    }

    private func temperatureKeys(withPrefix prefix: String, from keys: Set<String>) -> [String] {
        keys.filter { $0.hasPrefix(prefix) }
            .sorted()
    }

    private func meanTemperature(for keys: [String], with reader: AppleSMCReader) -> Double? {
        let values = keys.compactMap { sanitizedTemperature(reader.value(for: $0)) }
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }

    private func sanitizedTemperature(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (20...120).contains(value) else {
            return nil
        }

        return value
    }

    private func sampleFans(with reader: AppleSMCReader) -> [FanReading] {
        let fanCount = Int(reader.value(for: "FNum") ?? 0)
        guard fanCount > 0 else {
            return []
        }

        var fans: [FanReading] = []

        for index in 0..<fanCount {
            let currentKey = String(format: "F%dAc", index)
            let maxKey = String(format: "F%dMx", index)

            guard let current = reader.value(for: currentKey), current.isFinite, current >= 0 else {
                continue
            }

            let maximum = reader.value(for: maxKey)
                .flatMap { sanitizeRPM($0) }
            fans.append(
                FanReading(
                    number: index + 1,
                    currentRPM: current,
                    maximumRPM: maximum
                )
            )
        }

        return fans
    }

    private func sanitizeRPM(_ value: Double) -> Double? {
        guard value.isFinite, value > 0 else {
            return nil
        }

        return value
    }
}

private struct TemperatureSample {
    let soc: Double?
    let cpu: Double?
    let gpu: Double?
}
