import SwiftUI
import ActivityMonitorDashboardCore

struct CPUFrequencyHistogramView: View {
    let samples: [CPUFrequencySample]
    let capacity: Int
    let style: GraphStyle
    let performanceColor: Color
    let superColor: Color

    var body: some View {
        HistogramSurface {
            Canvas(rendersAsynchronously: true) { context, size in
                drawGrid(in: size, context: &context)

                switch style {
                case .bars:
                    drawCPUFrequencyBarGraph(
                        in: size,
                        context: &context,
                        samples: samples,
                        capacity: capacity,
                        performanceColor: performanceColor,
                        superColor: superColor
                    )
                case .filledLine:
                    drawCPUFrequencyLineGraph(
                        in: size,
                        context: &context,
                        samples: samples,
                        capacity: capacity,
                        performanceColor: performanceColor,
                        superColor: superColor
                    )
                }
            }
        }
        .accessibilityLabel("CPU frequency histogram")
    }
}

struct PowerHistogramView: View {
    let samples: [TotalPowerSample]
    let capacity: Int
    let style: GraphStyle
    let color: Color

    var body: some View {
        HistogramSurface {
            Canvas(rendersAsynchronously: true) { context, size in
                drawGrid(in: size, context: &context)

                switch style {
                case .bars:
                    drawValueBarGraph(
                        in: size,
                        context: &context,
                        values: samples.map(\.watts),
                        capacity: capacity,
                        color: color,
                        minimumDisplayMaximum: 10
                    )
                case .filledLine:
                    drawValueLineGraph(
                        in: size,
                        context: &context,
                        values: samples.map(\.watts),
                        capacity: capacity,
                        color: color,
                        minimumDisplayMaximum: 10
                    )
                }
            }
        }
        .accessibilityLabel("Total power histogram")
    }
}

struct ThermalStateHistogramView: View {
    let samples: [ThermalSample]
    let capacity: Int
    let style: GraphStyle
    let palette: PressureGraphColors

    var body: some View {
        HistogramSurface {
            Canvas(rendersAsynchronously: true) { context, size in
                drawGrid(in: size, context: &context)

                switch style {
                case .bars:
                    drawThermalBarGraph(
                        in: size,
                        context: &context,
                        samples: samples,
                        capacity: capacity,
                        palette: palette
                    )
                case .filledLine:
                    drawThermalLineGraph(
                        in: size,
                        context: &context,
                        samples: samples,
                        capacity: capacity,
                        palette: palette
                    )
                }
            }
        }
        .accessibilityLabel("Thermal state histogram")
    }
}

struct FanSpeedHistogramView: View {
    let samples: [ThermalSample]
    let capacity: Int
    let style: GraphStyle
    let fan1Color: Color
    let fan2Color: Color

    var body: some View {
        HistogramSurface {
            Canvas(rendersAsynchronously: true) { context, size in
                drawGrid(in: size, context: &context)

                switch style {
                case .bars:
                    drawFanSpeedBarGraph(
                        in: size,
                        context: &context,
                        samples: samples,
                        capacity: capacity,
                        fan1Color: fan1Color,
                        fan2Color: fan2Color
                    )
                case .filledLine:
                    drawFanSpeedLineGraph(
                        in: size,
                        context: &context,
                        samples: samples,
                        capacity: capacity,
                        fan1Color: fan1Color,
                        fan2Color: fan2Color
                    )
                }
            }
        }
        .accessibilityLabel("Fan speed histogram")
    }
}

private func drawCPUFrequencyBarGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    samples: [CPUFrequencySample],
    capacity: Int,
    performanceColor: Color,
    superColor: Color
) {
    let count = max(capacity, 1)
    let step = size.width / CGFloat(count)
    let totalBarWidth = max(2, step * 0.78)
    let segmentWidth = max(1, totalBarWidth * 0.42)
    let gap = max(1, totalBarWidth - (segmentWidth * 2))
    let offset = max(0, capacity - samples.count)

    for (index, sample) in samples.enumerated() {
        let originX = CGFloat(offset + index) * step + (step - totalBarWidth) / 2
        let performanceHeight = size.height * sample.performanceNormalized
        let superHeight = size.height * sample.superNormalized

        if performanceHeight > 0 {
            let performanceRect = CGRect(
                x: originX,
                y: size.height - performanceHeight,
                width: segmentWidth,
                height: performanceHeight
            )
            context.fill(Path(performanceRect), with: .color(performanceColor))
        }

        if superHeight > 0 {
            let superRect = CGRect(
                x: originX + segmentWidth + gap,
                y: size.height - superHeight,
                width: segmentWidth,
                height: superHeight
            )
            context.fill(Path(superRect), with: .color(superColor))
        }
    }
}

private func drawCPUFrequencyLineGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    samples: [CPUFrequencySample],
    capacity: Int,
    performanceColor: Color,
    superColor: Color
) {
    let performanceValues = samples.map(\.performanceNormalized)
    let superValues = samples.map(\.superNormalized)

    guard performanceValues.count > 1 || superValues.count > 1 else {
        drawCPUFrequencyBarGraph(
            in: size,
            context: &context,
            samples: samples,
            capacity: capacity,
            performanceColor: performanceColor,
            superColor: superColor
        )
        return
    }

    if performanceValues.count > 1 {
        drawOverlayLineGraph(
            in: size,
            context: &context,
            values: performanceValues,
            capacity: capacity,
            color: performanceColor
        )
    }

    if superValues.count > 1 {
        drawOverlayLineGraph(
            in: size,
            context: &context,
            values: superValues,
            capacity: capacity,
            color: superColor
        )
    }
}

private func drawValueBarGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    values: [Double],
    capacity: Int,
    color: Color,
    minimumDisplayMaximum: Double
) {
    let displayMaximum = displayMaximum(for: values, minimum: minimumDisplayMaximum)
    let normalizedValues = normalizedValues(values, displayMaximum: displayMaximum)
    let count = max(capacity, 1)
    let step = size.width / CGFloat(count)
    let barWidth = max(1, step * 0.72)
    let offset = max(0, capacity - normalizedValues.count)

    for (index, value) in normalizedValues.enumerated() {
        let height = size.height * value
        guard height > 0 else {
            continue
        }

        let rect = CGRect(
            x: CGFloat(offset + index) * step + (step - barWidth) / 2,
            y: size.height - height,
            width: barWidth,
            height: height
        )
        context.fill(Path(rect), with: .color(color))
    }
}

private func drawThermalBarGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    samples: [ThermalSample],
    capacity: Int,
    palette: PressureGraphColors
) {
    let temperatures = samples.map { max(0, $0.displayTemperatureCelsius ?? 0) }
    let displayMaximum = displayMaximum(for: temperatures, minimum: 100)
    let normalizedTemperatures = normalizedValues(temperatures, displayMaximum: displayMaximum)
    let count = max(capacity, 1)
    let step = size.width / CGFloat(count)
    let barWidth = max(1, step * 0.72)
    let offset = max(0, capacity - normalizedTemperatures.count)

    for (index, value) in normalizedTemperatures.enumerated() {
        let height = size.height * value
        guard height > 0 else {
            continue
        }

        let rect = CGRect(
            x: CGFloat(offset + index) * step + (step - barWidth) / 2,
            y: size.height - height,
            width: barWidth,
            height: height
        )
        context.fill(Path(rect), with: .color(palette.color(for: samples[index].thermalState)))
    }
}

private func drawThermalLineGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    samples: [ThermalSample],
    capacity: Int,
    palette: PressureGraphColors
) {
    let temperatures = samples.map { max(0, $0.displayTemperatureCelsius ?? 0) }
    let color = samples.last.map { palette.color(for: $0.thermalState) } ?? DashboardPalette.secondaryLabel

    drawValueLineGraph(
        in: size,
        context: &context,
        values: temperatures,
        capacity: capacity,
        color: color,
        minimumDisplayMaximum: 100
    )
}

private func drawFanSpeedBarGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    samples: [ThermalSample],
    capacity: Int,
    fan1Color: Color,
    fan2Color: Color
) {
    let fanSamples = fanStackSamples(from: samples)
    let count = max(capacity, 1)
    let step = size.width / CGFloat(count)
    let barWidth = max(1, step * 0.72)
    let offset = max(0, capacity - fanSamples.count)

    for (index, sample) in fanSamples.enumerated() {
        let x = CGFloat(offset + index) * step + (step - barWidth) / 2
        let fan1Height = size.height * sample.fan1Normalized
        let fan2Height = size.height * sample.fan2Normalized
        let totalHeight = fan1Height + fan2Height

        if fan1Height > 0 {
            let fan1Rect = CGRect(
                x: x,
                y: size.height - fan1Height,
                width: barWidth,
                height: fan1Height
            )
            context.fill(Path(fan1Rect), with: .color(fan1Color))
        }

        if fan2Height > 0 {
            let fan2Rect = CGRect(
                x: x,
                y: size.height - totalHeight,
                width: barWidth,
                height: fan2Height
            )
            context.fill(Path(fan2Rect), with: .color(fan2Color))
        }
    }
}

private func drawFanSpeedLineGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    samples: [ThermalSample],
    capacity: Int,
    fan1Color: Color,
    fan2Color: Color
) {
    let fanSamples = fanStackSamples(from: samples)
    let fan1Values = fanSamples.map(\.fan1Normalized)
    let totalValues = fanSamples.map(\.totalNormalized)

    guard fan1Values.count > 1 || totalValues.count > 1 else {
        drawFanSpeedBarGraph(
            in: size,
            context: &context,
            samples: samples,
            capacity: capacity,
            fan1Color: fan1Color,
            fan2Color: fan2Color
        )
        return
    }

    let fan1Points = normalizedPoints(for: fan1Values, in: size, capacity: capacity)
    let totalPoints = normalizedPoints(for: totalValues, in: size, capacity: capacity)

    let fan1Area = closedAreaPath(points: fan1Points, baselineY: size.height)
    context.fill(
        fan1Area,
        with: .linearGradient(
            Gradient(colors: [
                fan1Color.opacity(0.42),
                fan1Color.opacity(0.08),
            ]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        )
    )

    let fan2Band = stackedBandPath(lowerPoints: fan1Points, upperPoints: totalPoints)
    context.fill(
        fan2Band,
        with: .linearGradient(
            Gradient(colors: [
                fan2Color.opacity(0.44),
                fan2Color.opacity(0.10),
            ]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        )
    )

    context.stroke(linePath(points: fan1Points), with: .color(fan1Color), lineWidth: 1.5)
    context.stroke(linePath(points: totalPoints), with: .color(fan2Color), lineWidth: 2)
}

private func drawValueLineGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    values: [Double],
    capacity: Int,
    color: Color,
    minimumDisplayMaximum: Double
) {
    let displayMaximum = displayMaximum(for: values, minimum: minimumDisplayMaximum)
    let normalizedSeries = normalizedValues(values, displayMaximum: displayMaximum)

    guard normalizedSeries.count > 1 else {
        drawValueBarGraph(
            in: size,
            context: &context,
            values: values,
            capacity: capacity,
            color: color,
            minimumDisplayMaximum: minimumDisplayMaximum
        )
        return
    }

    drawOverlayLineGraph(
        in: size,
        context: &context,
        values: normalizedSeries,
        capacity: capacity,
        color: color
    )
}

private func drawOverlayLineGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    values: [Double],
    capacity: Int,
    color: Color
) {
    let points = normalizedPoints(for: values, in: size, capacity: capacity)

    context.fill(
        closedAreaPath(points: points, baselineY: size.height),
        with: .linearGradient(
            Gradient(colors: [
                color.opacity(0.40),
                color.opacity(0.08),
            ]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        )
    )
    context.stroke(linePath(points: points), with: .color(color), lineWidth: 2)
}

private func displayMaximum(for values: [Double], minimum: Double) -> Double {
    let measuredMaximum = values.max() ?? 0
    return max(minimum, measuredMaximum * 1.15)
}

private func normalizedValues(_ values: [Double], displayMaximum: Double) -> [Double] {
    guard displayMaximum > 0 else {
        return Array(repeating: 0, count: values.count)
    }

    return values.map { ($0 / displayMaximum).clamped(to: 0...1) }
}

private struct FanStackSample {
    let fan1Normalized: Double
    let fan2Normalized: Double

    var totalNormalized: Double {
        (fan1Normalized + fan2Normalized).clamped(to: 0...1)
    }
}

private func fanStackSamples(from samples: [ThermalSample]) -> [FanStackSample] {
    samples.map { sample in
        let fan1 = sample.fan(number: 1)
        let fan2 = sample.fan(number: 2)
        let fallbackMaximumRPM = sample.maximumFanRPM
        let fan1Maximum = resolvedFanMaximumRPM(for: fan1, fallback: fallbackMaximumRPM)
        let fan2Maximum = resolvedFanMaximumRPM(for: fan2, fallback: fallbackMaximumRPM)
        let combinedMaximum = fan1Maximum + fan2Maximum

        guard combinedMaximum > 0 else {
            return FanStackSample(fan1Normalized: 0, fan2Normalized: 0)
        }

        return FanStackSample(
            fan1Normalized: ((fan1?.currentRPM ?? 0) / combinedMaximum).clamped(to: 0...1),
            fan2Normalized: ((fan2?.currentRPM ?? 0) / combinedMaximum).clamped(to: 0...1)
        )
    }
}

private func resolvedFanMaximumRPM(for fan: FanReading?, fallback: Double?) -> Double {
    if let maximumRPM = fan?.maximumRPM, maximumRPM > 0 {
        return maximumRPM
    }

    if let fallback, fallback > 0 {
        return fallback
    }

    return max(0, fan?.currentRPM ?? 0)
}
