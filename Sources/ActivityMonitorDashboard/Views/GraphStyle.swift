import Foundation

enum GraphStyle: String, CaseIterable, Identifiable {
    case filledLine = "Filled Line"
    case bars = "Bars"

    var id: String {
        rawValue
    }
}
