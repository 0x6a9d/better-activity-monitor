import SwiftUI

struct MetricStat: Identifiable {
    let id: String
    let label: String
    let value: String
    let valueColor: Color

    init(label: String, value: String, valueColor: Color = .primary) {
        self.id = label
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }
}

struct MetricPanelView<Headline: View, Content: View, Footer: View>: View {
    let title: String
    let titleDetail: String?
    let accentColor: Color
    let stats: [MetricStat]
    let headlineView: Headline
    let content: Content
    let footer: Footer

    init(
        title: String,
        titleDetail: String? = nil,
        headline: String,
        accentColor: Color,
        stats: [MetricStat],
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) where Headline == Text {
        self.title = title
        self.titleDetail = titleDetail
        self.accentColor = accentColor
        self.stats = stats
        self.headlineView = Text(headline)
            .font(.title3.weight(.semibold))
            .foregroundStyle(accentColor)
        self.content = content()
        self.footer = footer()
    }

    init(
        title: String,
        titleDetail: String? = nil,
        accentColor: Color,
        stats: [MetricStat],
        @ViewBuilder headline: () -> Headline,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.titleDetail = titleDetail
        self.accentColor = accentColor
        self.stats = stats
        self.headlineView = headline()
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.headline.weight(.semibold))

                    if let titleDetail, !titleDetail.isEmpty {
                        Text("•")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DashboardPalette.secondaryLabel)

                        Text(titleDetail)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DashboardPalette.secondaryLabel)
                    }
                }

                Spacer()

                headlineView
            }

            content

            HStack(alignment: .bottom, spacing: 12) {
                HStack(spacing: 14) {
                    ForEach(stats) { stat in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.value)
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(stat.valueColor)

                            Text(stat.label)
                                .font(.caption)
                                .foregroundStyle(DashboardPalette.secondaryLabel)
                        }
                    }
                }

                Spacer(minLength: 12)

                footer
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DashboardPalette.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DashboardPalette.panelBorder, lineWidth: 1)
        )
    }
}
