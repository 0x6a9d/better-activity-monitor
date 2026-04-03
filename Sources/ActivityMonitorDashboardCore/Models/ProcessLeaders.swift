import Foundation

public struct ProcessLeader: Sendable, Equatable {
    public enum MetricKind: Sendable, Equatable {
        case percent
        case bytes
    }

    public let name: String
    public let metricKind: MetricKind
    public let numericValue: Double
    public let displayValue: String

    public init(
        name: String,
        metricKind: MetricKind,
        numericValue: Double,
        displayValue: String
    ) {
        self.name = name
        self.metricKind = metricKind
        self.numericValue = numericValue
        self.displayValue = displayValue
    }
}

public struct ProcessLeadersSnapshot: Sendable, Equatable {
    public let cpu: ProcessLeader?
    public let memory: ProcessLeader?
    public let gpu: ProcessLeader?

    public init(cpu: ProcessLeader?, memory: ProcessLeader?, gpu: ProcessLeader?) {
        self.cpu = cpu
        self.memory = memory
        self.gpu = gpu
    }

    public static let empty = ProcessLeadersSnapshot(cpu: nil, memory: nil, gpu: nil)
}
