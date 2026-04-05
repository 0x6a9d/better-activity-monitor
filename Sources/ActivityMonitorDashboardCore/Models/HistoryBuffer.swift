import Foundation

public struct HistoryBuffer<Element: Sendable>: Sendable {
    public let capacity: Int
    private var storage: [Element]

    public init(capacity: Int) {
        precondition(capacity > 0, "HistoryBuffer capacity must be greater than zero.")
        self.capacity = capacity
        self.storage = []
    }

    public var values: [Element] {
        storage
    }

    public var isEmpty: Bool {
        storage.isEmpty
    }

    public var last: Element? {
        storage.last
    }

    public mutating func append(_ element: Element) {
        storage.append(element)

        if storage.count > capacity {
            storage.removeFirst(storage.count - capacity)
        }
    }

    public mutating func appendIfChanged(_ element: Element) where Element: Equatable {
        guard last != element else {
            return
        }

        append(element)
    }
}
