import SwiftUI

struct OrderBookView: View {
    let bids: [OrderLevel]
    let asks: [OrderLevel]

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bids")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                OrderBookHeader()
                ForEach(bids.prefix(10)) { level in
                    OrderBookRow(price: level.price, size: level.size, isBid: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Asks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                OrderBookHeader()
                ForEach(asks.prefix(10)) { level in
                    OrderBookRow(price: level.price, size: level.size, isBid: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct OrderBookHeader: View {
    var body: some View {
        HStack {
            Text("Price")
            Spacer()
            Text("Size")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

private struct OrderBookRow: View {
    let price: Double
    let size: Double
    let isBid: Bool

    var body: some View {
        HStack {
            Text(formatPrice(price))
                .foregroundStyle(isBid ? .green : .red)
            Spacer()
            Text(formatPrice(size))
                .foregroundStyle(.primary)
        }
        .font(.caption2)
        .monospacedDigit()
    }
}
