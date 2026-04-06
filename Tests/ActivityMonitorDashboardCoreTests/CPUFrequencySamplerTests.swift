import Foundation
import Testing
@testable import ActivityMonitorDashboardCore

@Test
func cpuFrequencySamplerParsesModernAndLegacyDVFSTablesIntoGigahertz() {
    let modernData = dvfsData([2_100_000, 4_200_000])
    let legacyData = dvfsData([2_064_000_000, 4_128_000_000])

    let modernFrequencies = CPUFrequencySampler.parseFrequencies(from: modernData)
    let legacyFrequencies = CPUFrequencySampler.parseFrequencies(from: legacyData)

    #expect(modernFrequencies.count == 2)
    #expect(abs(modernFrequencies[0] - 2.1) < 0.001)
    #expect(abs(modernFrequencies[1] - 4.2) < 0.001)
    #expect(legacyFrequencies.count == 2)
    #expect(abs(legacyFrequencies[0] - 2.064) < 0.001)
    #expect(abs(legacyFrequencies[1] - 4.128) < 0.001)
}

@Test
func cpuFrequencySampleUsesWeightedOverallAverage() {
    let sample = CPUFrequencySample(
        performanceGHz: 2.4,
        superGHz: 4.2,
        performanceMaxGHz: 3.6,
        superMaxGHz: 4.8,
        performanceCoreCount: 12,
        superCoreCount: 6,
        isAvailable: true
    )

    #expect(abs(sample.overallGHz - 3.0) < 0.001)
    #expect(abs(sample.performanceNormalized - (2.4 / 3.6)) < 0.001)
    #expect(abs(sample.superNormalized - (4.2 / 4.8)) < 0.001)
}

@Test
func cpuFrequencySamplerInfersTierLabelsFromObservedChannelPrefixes() {
    let baseLabels = CPUFrequencySampler.tierLabels(
        forPerformancePrefixes: ["ECPU"],
        superPrefixes: ["PCPU"]
    )
    let proLabels = CPUFrequencySampler.tierLabels(
        forPerformancePrefixes: ["MCPU"],
        superPrefixes: ["PCPU"]
    )

    #expect(baseLabels.performance == .efficiency)
    #expect(baseLabels.super == .performance)
    #expect(proLabels.performance == .performance)
    #expect(proLabels.super == .superTier)
}

private func dvfsData(_ rawFrequencies: [UInt32]) -> Data {
    var data = Data()

    for frequency in rawFrequencies {
        var littleEndianFrequency = frequency.littleEndian
        var littleEndianVoltage: UInt32 = 0

        withUnsafeBytes(of: &littleEndianFrequency) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &littleEndianVoltage) { data.append(contentsOf: $0) }
    }

    return data
}
