import Foundation
import IOKit

final class AppleSMCReader {
    private enum Command: UInt8 {
        case readBytes = 5
        case readIndex = 8
        case readKeyInfo = 9
    }

    private struct KeyData {
        typealias Bytes = (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
        )

        struct Info {
            var dataSize: IOByteCount32 = 0
            var dataType: UInt32 = 0
            var dataAttributes: UInt8 = 0
        }

        var key: UInt32 = 0
        var vers = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt16(0))
        var pLimitData = (UInt16(0), UInt16(0), UInt32(0), UInt32(0), UInt32(0))
        var keyInfo = Info()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: Bytes = (
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    private struct Value {
        var key: String
        var dataSize: UInt32 = 0
        var dataType: String = ""
        var bytes: [UInt8] = Array(repeating: 0, count: 32)
    }

    private let connection: io_connect_t
    private var cachedKeys: [String]?

    init?() {
        var iterator: io_iterator_t = 0
        let matchResult = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC"),
            &iterator
        )
        guard matchResult == kIOReturnSuccess else {
            return nil
        }

        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        guard device != 0 else {
            return nil
        }

        var connection: io_connect_t = 0
        let openResult = IOServiceOpen(device, mach_task_self_, 0, &connection)
        IOObjectRelease(device)
        guard openResult == kIOReturnSuccess else {
            return nil
        }

        self.connection = connection
    }

    deinit {
        IOServiceClose(connection)
    }

    func value(for key: String) -> Double? {
        guard let value = readValue(for: key) else {
            return nil
        }

        switch value.dataType {
        case "ui8 ":
            return Double(value.bytes[0])
        case "ui16":
            return Double(UInt16(value.bytes[0], value.bytes[1]))
        case "ui32":
            return Double(UInt32(value.bytes[0], value.bytes[1], value.bytes[2], value.bytes[3]))
        case "sp78":
            return Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1])) / 256
        case "fpe2":
            return Double((Int(value.bytes[0]) << 6) + (Int(value.bytes[1]) >> 2))
        case "flt ":
            return value.bytes.prefix(4).withUnsafeBytes { bytes in
                Double(bytes.load(as: Float.self))
            }
        default:
            return nil
        }
    }

    func allKeys() -> [String] {
        if let cachedKeys {
            return cachedKeys
        }

        let count = Int(value(for: "#KEY") ?? 0)
        let keys = (0..<count).compactMap(key(at:))
        cachedKeys = keys
        return keys
    }

    private func key(at index: Int) -> String? {
        var input = KeyData()
        var output = KeyData()
        input.data8 = Command.readIndex.rawValue
        input.data32 = UInt32(index)

        let result = call(index: 2, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            return nil
        }

        return output.key.stringValue
    }

    private func readValue(for key: String) -> Value? {
        var value = Value(key: key)
        guard read(&value) == kIOReturnSuccess else {
            return nil
        }
        return value
    }

    private func read(_ value: inout Value) -> kern_return_t {
        var input = KeyData()
        var output = KeyData()
        input.key = FourCharCode(value.key)
        input.data8 = Command.readKeyInfo.rawValue

        var result = call(index: 2, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            return result
        }

        value.dataSize = UInt32(output.keyInfo.dataSize)
        value.dataType = output.keyInfo.dataType.stringValue
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = Command.readBytes.rawValue

        result = call(index: 2, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            return result
        }

        let bytes = Mirror(reflecting: output.bytes).children.compactMap { $0.value as? UInt8 }
        for (offset, byte) in bytes.enumerated() where offset < value.bytes.count {
            value.bytes[offset] = byte
        }

        return result
    }

    private func call(index: UInt8, input: inout KeyData, output: inout KeyData) -> kern_return_t {
        var outputSize = MemoryLayout<KeyData>.stride
        return IOConnectCallStructMethod(
            connection,
            UInt32(index),
            &input,
            MemoryLayout<KeyData>.stride,
            &output,
            &outputSize
        )
    }
}

private extension FourCharCode {
    init(_ string: String) {
        precondition(string.count == 4)
        self = string.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    var stringValue: String {
        let scalars = [
            UnicodeScalar(self >> 24 & 0xff)!,
            UnicodeScalar(self >> 16 & 0xff)!,
            UnicodeScalar(self >> 8 & 0xff)!,
            UnicodeScalar(self & 0xff)!
        ]
        return String(String.UnicodeScalarView(scalars))
    }
}

private extension UInt16 {
    init(_ a: UInt8, _ b: UInt8) {
        self = (UInt16(a) << 8) | UInt16(b)
    }
}

private extension UInt32 {
    init(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) {
        self = (UInt32(a) << 24) | (UInt32(b) << 16) | (UInt32(c) << 8) | UInt32(d)
    }
}
