import SwiftUI
import Charts

/// Last 30 days as a solid line, next 30 as a dashed projection in the gold
/// accent — two distinct `foregroundStyle` values keep Swift Charts from
/// joining them into a single path.
struct ForecastChart: View {
    let data: ForecastData

    private var allValues: [Double] {
        (data.past + data.projected).map(\.value)
    }

    private var valueRange: ClosedRange<Double> {
        let minV = allValues.min() ?? 0
        let maxV = allValues.max() ?? 1
        let padding = max((maxV - minV) * 0.15, 1)
        return (minV - padding)...(maxV + padding)
    }

    var body: some View {
        Chart {
            ForEach(data.past) { point in
                LineMark(x: .value("Date", point.date), y: .value("Balance", point.value))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(MonetaColor.textPrimary)
            }
            ForEach(data.projected) { point in
                LineMark(x: .value("Date", point.date), y: .value("Balance", point.value))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 6]))
                    .foregroundStyle(MonetaColor.accent)
            }
            if let today = data.past.last {
                PointMark(x: .value("Date", today.date), y: .value("Balance", today.value))
                    .symbolSize(70)
                    .foregroundStyle(MonetaColor.textPrimary)
                    .annotation(position: .top, spacing: 6) {
                        Text("Today \(Currency.string(today.value))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MonetaColor.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(MonetaColor.canvas, in: Capsule())
                    }
            }
            if let end = data.projected.last {
                PointMark(x: .value("Date", end.date), y: .value("Balance", end.value))
                    .symbolSize(70)
                    .foregroundStyle(MonetaColor.accent)
                    .annotation(position: .top, spacing: 6) {
                        Text(Currency.string(end.value))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MonetaColor.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(MonetaColor.canvas, in: Capsule())
                    }
            }
        }
        .chartYScale(domain: valueRange)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityElement()
        .accessibilityLabel("30 day balance forecast")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let today = data.past.last, let end = data.projected.last else { return "" }
        return String.localized("\(Currency.string(today.value)) today, projected \(Currency.string(end.value)) by \(data.projectedDateLabel)")
    }
}
