import Foundation

@MainActor
enum MetricFormatting {
    private struct DecimalFormatterKey: Hashable {
        let minimumFractionDigits: Int
        let maximumFractionDigits: Int
    }

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

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static var decimalFormatterCache: [DecimalFormatterKey: NumberFormatter] = [
        DecimalFormatterKey(minimumFractionDigits: 0, maximumFractionDigits: 0): wholeNumberFormatter,
        DecimalFormatterKey(minimumFractionDigits: 1, maximumFractionDigits: 1): oneDecimalFormatter,
    ]

    private static func decimalFormatter(
        minimumFractionDigits: Int,
        maximumFractionDigits: Int
    ) -> NumberFormatter {
        let key = DecimalFormatterKey(
            minimumFractionDigits: minimumFractionDigits,
            maximumFractionDigits: maximumFractionDigits
        )

        if let formatter = decimalFormatterCache[key] {
            return formatter
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        decimalFormatterCache[key] = formatter
        return formatter
    }

    private static func decimalString(
        _ value: Double,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int
    ) -> String {
        let formatter = decimalFormatter(
            minimumFractionDigits: minimumFractionDigits,
            maximumFractionDigits: maximumFractionDigits
        )

        return formatter.string(from: NSNumber(value: value))
            ?? oneDecimalFormatter.string(from: NSNumber(value: value))
            ?? "0.0"
    }

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
        let formatted = decimalString(
            value,
            minimumFractionDigits: minimumFractionDigits,
            maximumFractionDigits: maximumFractionDigits
        )
        let suffix = includeSpace ? " W" : "W"
        return "\(formatted)\(suffix)"
    }

    static func gigahertz(_ value: Double, fractionDigits: Int = 1) -> String {
        let formatted = decimalString(
            value,
            minimumFractionDigits: fractionDigits,
            maximumFractionDigits: fractionDigits
        )
        return "\(formatted)GHz"
    }

    static func relativeDate(_ date: Date?) -> String {
        guard let date else {
            return "Waiting for samples"
        }

        return "Updated \(relativeDateFormatter.localizedString(for: date, relativeTo: Date()))"
    }
}
