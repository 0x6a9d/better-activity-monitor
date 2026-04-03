import Foundation

public enum PressureLevel: String, CaseIterable, Sendable {
    case good
    case moderate
    case heavy

    public init(
        normalizedValue: Double,
        warningThreshold: Double = 0.60,
        criticalThreshold: Double = 0.82
    ) {
        let value = normalizedValue.clamped(to: 0...1)

        switch value {
        case criticalThreshold...:
            self = .heavy
        case warningThreshold...:
            self = .moderate
        default:
            self = .good
        }
    }

    public var title: String {
        switch self {
        case .good:
            "Good"
        case .moderate:
            "Moderate"
        case .heavy:
            "Heavy"
        }
    }
}

public extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
