import SwiftUI
import Charts

/// The Home balance chart: a bare line with a dashed baseline at the period's
/// opening value, and a drag-to-scrub gesture that reports the nearest point
/// back to the caller so it can update the headline balance/delta text —
/// mirroring how the prototype's chart drives the numbers above it.
struct BalanceLineChart: View {
    let points: [BalancePoint]
    @Binding var selectedIndex: Int?
    /// Where a balance-sheet event (asset/liability added, changed, removed)
    /// falls on the line — plotted at the nearest existing point's own value
    /// so a marker always sits exactly on the line rather than inventing a
    /// Y-coordinate. Defaults to none so every other chart usage is unaffected.
    var events: [BalancePoint] = []

    private var valueRange: ClosedRange<Double> {
        let values = points.map(\.value)
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let padding = max((maxV - minV) * 0.12, 1)
        return (minV - padding)...(maxV + padding)
    }

    var body: some View {
        Chart {
            if let first = points.first {
                RuleMark(y: .value("Start", first.value))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [1, 5]))
                    .foregroundStyle(MonetaColor.textTertiary)
            }

            ForEach(points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Balance", point.value))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(MonetaColor.textPrimary)
            }

            ForEach(events) { event in
                PointMark(x: .value("Date", event.date), y: .value("Balance", event.value))
                    .symbol(.diamond)
                    .symbolSize(70)
                    .foregroundStyle(MonetaColor.accent)
            }

            if let selectedIndex, points.indices.contains(selectedIndex) {
                let point = points[selectedIndex]
                RuleMark(x: .value("Date", point.date))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(MonetaColor.textTertiary)
                PointMark(x: .value("Date", point.date), y: .value("Balance", point.value))
                    .symbolSize(90)
                    .foregroundStyle(MonetaColor.textPrimary)
            }
        }
        .chartYScale(domain: valueRange)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                updateSelection(at: drag.location, proxy: proxy, geometry: geo)
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedIndex = nil
                                }
                            }
                    )
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Balance chart")
        .accessibilityValue(accessibilitySummary)
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let origin = geometry[plotFrameAnchor].origin
        let xInPlot = location.x - origin.x
        guard let date: Date = proxy.value(atX: xInPlot) else { return }
        guard let nearest = points.indices.min(by: {
            abs(points[$0].date.timeIntervalSince(date)) < abs(points[$1].date.timeIntervalSince(date))
        }) else { return }
        if nearest != selectedIndex {
            selectedIndex = nearest
        }
    }

    private var accessibilitySummary: String {
        guard let first = points.first, let last = points.last else { return "" }
        let diff = last.value - first.value
        let lastValue = Currency.string(last.value)
        let diffAmount = Currency.string(abs(diff))
        // Two complete sentences, not a composed fragment — concatenating a
        // translated "up"/"down" word into one template doesn't hold up
        // across languages with different grammar.
        return diff >= 0
            ? String.localized("\(lastValue), up \(diffAmount) over the period")
            : String.localized("\(lastValue), down \(diffAmount) over the period")
    }
}
