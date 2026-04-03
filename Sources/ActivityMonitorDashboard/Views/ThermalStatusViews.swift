import SwiftUI
import ActivityMonitorDashboardCore

struct FanRingsView: View {
    let fans: [FanReading]

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(fans) { fan in
                FanRingView(fan: fan)
            }
        }
    }
}

private struct FanRingView: View {
    let fan: FanReading

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(DashboardPalette.windowBackground.opacity(0.8), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: fan.normalizedSpeed ?? 0)
                    .stroke(
                        ringColor(for: fan),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("Fan \(fan.number)")
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(DashboardPalette.secondaryLabel)

                    Text(MetricFormatting.percent(fan.normalizedSpeed ?? 0))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.primary)
                }
            }
            .frame(width: 64, height: 64)

            Text(rpmText(for: fan))
                .font(.caption2.monospacedDigit())
                .padding(.top, 2)
                .multilineTextAlignment(.center)
                .foregroundStyle(DashboardPalette.secondaryLabel)
                .lineLimit(2)
        }
    }

    private func rpmText(for fan: FanReading) -> String {
        if let maximumRPM = fan.maximumRPM {
            return "\(MetricFormatting.number(fan.currentRPM)) / \(MetricFormatting.number(maximumRPM)) RPM"
        }

        return MetricFormatting.rpm(fan.currentRPM)
    }

    private func ringColor(for fan: FanReading) -> Color {
        let value = fan.normalizedSpeed ?? 0

        switch value {
        case 0.82...:
            return DashboardPalette.heavy
        case 0.55...:
            return DashboardPalette.moderate
        default:
            return DashboardPalette.good
        }
    }
}
