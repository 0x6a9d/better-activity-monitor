import Foundation

@MainActor
enum MetricFormatting {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let precisePercentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    private static let oneDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    private static let wholeNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func bytes(_ value: UInt64) -> String {
        byteFormatter.string(fromByteCount: Int64(value))
    }

    static func percent(_ value: Double, precise: Bool = false) -> String {
        let formatter = precise ? precisePercentFormatter : percentFormatter
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }

    static func temperature(_ value: Double) -> String {
        let formatted = wholeNumberFormatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(formatted) \u{00B0}C"
    }

    static func rpm(_ value: Double) -> String {
        let formatted = wholeNumberFormatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(formatted) RPM"
    }

    static func number(_ value: Double) -> String {
        wholeNumberFormatter.string(from: NSNumber(value: value)) ?? "0"
    }

    static func watts(
        _ value: Double,
        minimumFractionDigits: Int = 1,
        maximumFractionDigits: Int = 1,
        includeSpace: Bool = true
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits

        let formatted = formatter.string(from: NSNumber(value: value))
            ?? oneDecimalFormatter.string(from: NSNumber(value: value))
            ?? "0.0"
        let suffix = includeSpace ? " W" : "W"
        return "\(formatted)\(suffix)"
    }

    static func gigahertz(_ value: Double, fractionDigits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        let formatted = formatter.string(from: NSNumber(value: value))
            ?? oneDecimalFormatter.string(from: NSNumber(value: value))
            ?? "0.0"
        return "\(formatted)GHz"
    }

    static func relativeDate(_ date: Date?) -> String {
        guard let date else {
            return "Waiting for samples"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}
