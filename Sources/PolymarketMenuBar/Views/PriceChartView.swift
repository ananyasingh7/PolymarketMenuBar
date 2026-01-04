import SwiftUI

struct PriceChartView: View {
    let points: [PricePoint]
    let lineColor: Color

    var body: some View {
        GeometryReader { geometry in
            if !points.isEmpty {
                let minPrice = points.map { $0.price }.min() ?? 0
                let maxPrice = points.map { $0.price }.max() ?? 1
                let minTime = points.map { $0.timestamp.timeIntervalSince1970 }.min() ?? 0
                let maxTime = points.map { $0.timestamp.timeIntervalSince1970 }.max() ?? 1
                let priceRange = max(maxPrice - minPrice, 0.0001)
                let timeRange = max(maxTime - minTime, 0.0001)

                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = CGFloat((point.timestamp.timeIntervalSince1970 - minTime) / timeRange) * geometry.size.width
                        let yPosition = (point.price - minPrice) / priceRange
                        let y = geometry.size.height - (CGFloat(yPosition) * geometry.size.height)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                if let point = points.first, points.count == 1 {
                    let x = geometry.size.width / 2
                    let yPosition = (point.price - minPrice) / priceRange
                    let y = geometry.size.height - (CGFloat(yPosition) * geometry.size.height)
                    Circle()
                        .fill(lineColor)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
            } else {
                VStack {
                    Text("No price history")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
