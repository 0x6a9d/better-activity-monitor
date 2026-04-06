import Darwin

enum PlatformSupport {
    static func isSupportedHardware() -> Bool {
        isAppleSiliconHardware(arm64Flag: arm64Flag())
    }

    static func isAppleSiliconHardware(arm64Flag: Int32?) -> Bool {
        arm64Flag == 1
    }

    private static func arm64Flag() -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size

        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        guard result == 0 else {
            return nil
        }

        return value
    }
}
