import SwiftUI

struct MarketRowView: View {
    let market: MarketSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(market.marketTitle)
                .font(.headline)
                .lineLimit(2)
            Text(market.eventTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let yesPrice = market.yesPrice {
                HStack(spacing: 8) {
                    Text("Yes \(formatPercent(yesPrice))")
                        .font(.caption2)
                    Text(moneylineOdds(probability: yesPrice))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Price unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
