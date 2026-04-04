import SwiftUI
import ActivityMonitorDashboardCore

struct CPULoadHistogramView: View {
    let samples: [CPUSample]
    let capacity: Int
    let style: GraphStyle
    let userColor: Color
    let systemColor: Color

    var body: some View {
        HistogramSurface {
            Canvas(rendersAsynchronously: true) { context, size in
                drawGrid(in: size, context: &context)

                switch style {
                case .bars:
                    drawCPUBarGraph(
                        in: size,
                        context: &context,
                        samples: samples,
                        capacity: capacity,
                        userColor: userColor,
                        systemColor: systemColor
                    )
                case .filledLine:
                    drawCPULineGraph(
                        in: size,
                        context: &context,
                        samples: samples,
                        capacity: capacity,
                        userColor: userColor,
                        systemColor: systemColor
                    )
                }
            }
        }
        .accessibilityLabel("CPU load histogram")
    }
}

struct PressureHistogramView: View {
    let samples: [PressureHistogramSample]
    let capacity: Int
    let isUnavailable: Bool
    let style: GraphStyle
    let palette: PressureGraphColors?
    let colorOverride: Color?

    var body: some View {
        HistogramSurface {
            ZStack {
                Canvas(rendersAsynchronously: true) { context, size in
                    drawGrid(in: size, context: &context)

                    switch style {
                    case .bars:
                        drawPressureBarGraph(
                            in: size,
                            context: &context,
                            samples: samples,
                            capacity: capacity,
                            palette: palette,
                            colorOverride: colorOverride
                        )
                    case .filledLine:
                        drawPressureLineGraph(
                            in: size,
                            context: &context,
                            samples: samples,
                            capacity: capacity,
                            palette: palette,
                            colorOverride: colorOverride
                        )
                    }
                }

                if isUnavailable {
                    Text("GPU metrics unavailable on this Mac")
                        .font(.caption)
                        .foregroundStyle(DashboardPalette.secondaryLabel)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                }
            }
        }
    }
}

struct HistogramSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(height: 108)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DashboardPalette.windowBackground.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardPalette.panelBorder.opacity(0.5), lineWidth: 1)
            )
    }
}

private func drawCPUBarGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    samples: [CPUSample],
    capacity: Int,
    userColor: Color,
    systemColor: Color
) {
    let count = max(capacity, 1)
    let step = size.width / CGFloat(count)
    let barWidth = max(1, step * 0.72)
    let offset = max(0, capacity - samples.count)

    for (index, sample) in samples.enumerated() {
        let x = CGFloat(offset + index) * step + (step - barWidth) / 2
        let totalHeight = size.height * sample.totalUsage
        let systemHeight = size.height * sample.systemUsage
        let userHeight = size.height * sample.userUsage

        if systemHeight > 0 {
            let systemRect = CGRect(
                x: x,
                y: size.height - systemHeight,
                width: barWidth,
                height: systemHeight
            )
            context.fill(Path(systemRect), with: .color(systemColor))
        }

        if userHeight > 0 {
            let userRect = CGRect(
                x: x,
                y: size.height - totalHeight,
                width: barWidth,
                height: userHeight
            )
            context.fill(Path(userRect), with: .color(userColor))
        }
    }
}

private func drawPressureBarGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    samples: [PressureHistogramSample],
    capacity: Int,
    palette: PressureGraphColors?,
    colorOverride: Color?
) {
    let count = max(capacity, 1)
    let step = size.width / CGFloat(count)
    let barWidth = max(1, step * 0.72)
    let offset = max(0, capacity - samples.count)

    for (index, sample) in samples.enumerated() {
        let x = CGFloat(offset + index) * step + (step - barWidth) / 2
        let height = size.height * sample.value

        guard height > 0 else {
            continue
        }

        let rect = CGRect(
            x: x,
            y: size.height - height,
            width: barWidth,
            height: height
        )

        let color = colorOverride ?? palette?.color(for: sample.level) ?? sample.level.histogramColor
        context.fill(Path(rect), with: .color(color))
    }
}

private func drawCPULineGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    samples: [CPUSample],
    capacity: Int,
    userColor: Color,
    systemColor: Color
) {
    let systemValues = samples.map(\.systemUsage)
    let totalValues = samples.map(\.totalUsage)

    guard totalValues.count > 1 else {
        drawCPUBarGraph(
            in: size,
            context: &context,
            samples: samples,
            capacity: capacity,
            userColor: userColor,
            systemColor: systemColor
        )
        return
    }

    let systemPoints = normalizedPoints(for: systemValues, in: size, capacity: capacity)
    let totalPoints = normalizedPoints(for: totalValues, in: size, capacity: capacity)

    let systemArea = closedAreaPath(points: systemPoints, baselineY: size.height)
    context.fill(
        systemArea,
        with: .linearGradient(
            Gradient(colors: [
                systemColor.opacity(0.42),
                systemColor.opacity(0.08),
            ]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        )
    )

    let userBand = stackedBandPath(lowerPoints: systemPoints, upperPoints: totalPoints)
    context.fill(
        userBand,
        with: .linearGradient(
            Gradient(colors: [
                userColor.opacity(0.48),
                userColor.opacity(0.10),
            ]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        )
    )

    context.stroke(linePath(points: systemPoints), with: .color(systemColor), lineWidth: 1.5)
    context.stroke(linePath(points: totalPoints), with: .color(userColor), lineWidth: 2)
}

private func drawPressureLineGraph(
    in size: CGSize,
    context: inout GraphicsContext,
    samples: [PressureHistogramSample],
    capacity: Int,
    palette: PressureGraphColors?,
    colorOverride: Color?
) {
    guard samples.count > 1 else {
        drawPressureBarGraph(
            in: size,
            context: &context,
            samples: samples,
            capacity: capacity,
            palette: palette,
            colorOverride: colorOverride
        )
        return
    }

    let values = samples.map(\.value)
    let points = normalizedPoints(for: values, in: size, capacity: capacity)
    let color = colorOverride
        ?? samples.last.map { palette?.color(for: $0.level) ?? $0.level.histogramColor }
        ?? DashboardPalette.good

    context.fill(
        closedAreaPath(points: points, baselineY: size.height),
        with: .linearGradient(
            Gradient(colors: [
                color.opacity(0.45),
                color.opacity(0.08),
            ]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        )
    )
    context.stroke(linePath(points: points), with: .color(color), lineWidth: 2)
}

func normalizedPoints(
    for values: [Double],
    in size: CGSize,
    capacity: Int
) -> [CGPoint] {
    let count = max(capacity, 1)
    let step = size.width / CGFloat(count)
    let offset = max(0, capacity - values.count)

    return values.enumerated().map { index, value in
        CGPoint(
            x: CGFloat(offset + index) * step + (step / 2),
            y: size.height - (size.height * value.clamped(to: 0...1))
        )
    }
}

func linePath(points: [CGPoint]) -> Path {
    Path { path in
        guard let first = points.first else {
            return
        }

        path.move(to: first)

        for point in points.dropFirst() {
            path.addLine(to: point)
        }
    }
}

func closedAreaPath(points: [CGPoint], baselineY: CGFloat) -> Path {
    Path { path in
        guard let first = points.first,
              let last = points.last
        else {
            return
        }

        path.move(to: CGPoint(x: first.x, y: baselineY))
        path.addLine(to: first)

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        path.addLine(to: CGPoint(x: last.x, y: baselineY))
        path.closeSubpath()
    }
}

func stackedBandPath(lowerPoints: [CGPoint], upperPoints: [CGPoint]) -> Path {
    Path { path in
        guard let firstUpper = upperPoints.first,
              let lastLower = lowerPoints.last
        else {
            return
        }

        path.move(to: firstUpper)

        for point in upperPoints.dropFirst() {
            path.addLine(to: point)
        }

        path.addLine(to: lastLower)

        for point in lowerPoints.dropLast().reversed() {
            path.addLine(to: point)
        }

        path.closeSubpath()
    }
}

func drawGrid(in size: CGSize, context: inout GraphicsContext) {
    for fraction in stride(from: 0.25, through: 0.75, by: 0.25) {
        var line = Path()
        let y = size.height * fraction
        line.move(to: CGPoint(x: 0, y: y))
        line.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(line, with: .color(DashboardPalette.grid), lineWidth: 1)
    }
}
