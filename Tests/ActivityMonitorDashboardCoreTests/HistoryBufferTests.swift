import Testing
@testable import ActivityMonitorDashboardCore

@Test
func historyBufferDropsOldestSamplesWhenCapacityIsExceeded() {
    var buffer = HistoryBuffer<Int>(capacity: 3)

    buffer.append(1)
    buffer.append(2)
    buffer.append(3)
    buffer.append(4)

    #expect(buffer.values == [2, 3, 4])
}
