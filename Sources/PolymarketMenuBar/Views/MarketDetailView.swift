import SwiftUI

struct MarketDetailView: View {
    let market: MarketSummary

    @StateObject private var socket = MarketWebSocket()
    @State private var priceHistory: [PricePoint] = []
    @State private var isLoadingHistory = false
    @State private var orderBookFallback: OrderBookSnapshot? = nil
    @State private var lastTradeFallback: Double? = nil
    @State private var pollTask: Task<Void, Never>? = nil

    private let api = PolymarketAPI()

    private var displayedBook: OrderBookSnapshot {
        if socket.orderBook.bids.isEmpty && socket.orderBook.asks.isEmpty {
            return orderBookFallback ?? OrderBookSnapshot(bids: [], asks: [], lastUpdated: Date())
        }
        return socket.orderBook
    }

    private var livePrice: Double? {
        if let bestBid = displayedBook.bids.first?.price, let bestAsk = displayedBook.asks.first?.price {
            return (bestBid + bestAsk) / 2
        }
        if let trade = socket.lastTradePrice ?? lastTradeFallback {
            return trade
        }
        return market.yesPrice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                outcomesSection
                priceSection
                chartSection
                orderBookSection
            }
            .padding(16)
        }
        .task(id: market.id) {
            await loadMarket()
        }
        .onDisappear {
            stopPolling()
            socket.disconnect()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(market.marketTitle)
                .font(.title2)
                .bold()
            Text(market.eventTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(socket.isConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(socket.isConnected ? "Live" : "Offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var outcomesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Outcomes")
                .font(.headline)
            HStack(spacing: 12) {
                OutcomeCard(title: market.outcomes.first ?? "Yes", price: market.yesPrice)
                if market.outcomes.count > 1 {
                    OutcomeCard(title: market.outcomes[1], price: market.noPrice)
                }
            }
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Moneyline")
                .font(.headline)
            HStack(spacing: 16) {
                if let livePrice {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatPercent(livePrice))
                            .font(.title)
                            .bold()
                        Text(moneylineOdds(probability: livePrice))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("--")
                        .font(.title)
                        .bold()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Last update")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(displayedBook.lastUpdated.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                }
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Moneyline chart")
                    .font(.headline)
                if isLoadingHistory {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            PriceChartView(points: priceHistory, lineColor: .blue)
                .frame(height: 180)
        }
    }

    private var orderBookSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Order book (Yes token)")
                .font(.headline)
            OrderBookView(bids: displayedBook.bids, asks: displayedBook.asks)
        }
    }

    private func loadMarket() async {
        socket.disconnect()
        stopPolling()
        priceHistory = []
        orderBookFallback = nil
        lastTradeFallback = nil

        guard let tokenId = market.yesTokenId else { return }

        socket.connect(tokenId: tokenId)
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            async let history = api.fetchPriceHistory(tokenId: tokenId)
            async let book = api.fetchOrderBook(tokenId: tokenId)
            async let lastTrade = api.fetchLastTradePrice(tokenId: tokenId)
            priceHistory = try await history
            orderBookFallback = try await book
            lastTradeFallback = try await lastTrade
        } catch {
            // Leave partial data in place if any call fails.
        }

        startPolling(tokenId: tokenId)
    }

    private func startPolling(tokenId: String) {
        pollTask?.cancel()
        pollTask = Task {
            var tick = 0
            while !Task.isCancelled {
                do {
                    async let book = api.fetchOrderBook(tokenId: tokenId)
                    async let lastTrade = api.fetchLastTradePrice(tokenId: tokenId)
                    let fetchedBook = try await book
                    let fetchedTrade = try await lastTrade
                    await MainActor.run {
                        orderBookFallback = fetchedBook
                        lastTradeFallback = fetchedTrade
                    }
                } catch {
                    // Ignore transient polling failures.
                }

                if tick % 4 == 0 {
                    if let history = try? await api.fetchPriceHistory(tokenId: tokenId) {
                        await MainActor.run {
                            priceHistory = history
                        }
                    }
                }

                tick += 1
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}

private struct OutcomeCard: View {
    let title: String
    let price: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let price {
                Text(formatPercent(price))
                    .font(.headline)
                Text(moneylineOdds(probability: price))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .font(.headline)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
