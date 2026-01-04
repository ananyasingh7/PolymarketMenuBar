import Foundation

struct PolymarketAPI {
    private let gammaBase = URL(string: "https://gamma-api.polymarket.com")!
    private let clobBase = URL(string: "https://clob.polymarket.com")!

    func fetchMarkets(query: String?, limit: Int = 30) async throws -> [MarketSummary] {
        let trimmed = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let events: [GammaEvent]
        if trimmed.isEmpty {
            events = try await fetchActiveEvents(limit: limit)
        } else {
            events = try await searchEvents(query: trimmed, limitPerType: limit)
        }

        let summaries: [MarketSummary] = events.flatMap { event in
            event.markets.compactMap { market in
                let title = market.question ?? market.title ?? market.slug ?? "Market"
                let outcomes = market.outcomes?.values ?? []
                let outcomePrices = market.outcomePrices?.values ?? []
                let clobTokenIds = market.clobTokenIds?.values ?? []
                if clobTokenIds.isEmpty {
                    return nil
                }
                return MarketSummary(
                    id: market.id,
                    eventTitle: event.title ?? event.slug ?? "Event",
                    marketTitle: title,
                    outcomes: outcomes,
                    outcomePrices: outcomePrices,
                    clobTokenIds: clobTokenIds,
                    conditionId: market.conditionId
                )
            }
        }
        return summaries
    }

    func fetchActiveEvents(limit: Int) async throws -> [GammaEvent] {
        var components = URLComponents(url: gammaBase.appendingPathComponent("events"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "active", value: "true"),
            URLQueryItem(name: "closed", value: "false"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "order", value: "id"),
            URLQueryItem(name: "ascending", value: "false")
        ]
        guard let url = components?.url else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([GammaEvent].self, from: data)
    }

    func searchEvents(query: String, limitPerType: Int) async throws -> [GammaEvent] {
        var components = URLComponents(url: gammaBase.appendingPathComponent("public-search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit_per_type", value: String(limitPerType)),
            URLQueryItem(name: "events_status", value: "active")
        ]
        guard let url = components?.url else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(GammaSearchResponse.self, from: data).events
    }

    func fetchOrderBook(tokenId: String) async throws -> OrderBookSnapshot {
        var components = URLComponents(url: clobBase.appendingPathComponent("book"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "token_id", value: tokenId)
        ]
        guard let url = components?.url else {
            return OrderBookSnapshot(bids: [], asks: [], lastUpdated: Date())
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OrderBookResponse.self, from: data)
        let bidsRaw: [OrderLevelRaw] = response.bids ?? response.buys ?? []
        let asksRaw: [OrderLevelRaw] = response.asks ?? response.sells ?? []
        let bids: [OrderLevel] = bidsRaw.compactMap { level in
            guard let price = Double(level.price), let size = Double(level.size) else { return nil }
            return OrderLevel(price: price, size: size)
        }.sorted { $0.price > $1.price }
        let asks: [OrderLevel] = asksRaw.compactMap { level in
            guard let price = Double(level.price), let size = Double(level.size) else { return nil }
            return OrderLevel(price: price, size: size)
        }.sorted { $0.price < $1.price }
        return OrderBookSnapshot(bids: bids, asks: asks, lastUpdated: Date())
    }

    func fetchPriceHistory(tokenId: String, interval: String = "1d") async throws -> [PricePoint] {
        var components = URLComponents(url: clobBase.appendingPathComponent("prices-history"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "market", value: tokenId),
            URLQueryItem(name: "interval", value: interval)
        ]
        guard let url = components?.url else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PriceHistoryResponse.self, from: data)
        return response.history.map { point in
            PricePoint(timestamp: Date(timeIntervalSince1970: point.timestamp), price: point.price)
        }
    }

    func fetchLastTradePrice(tokenId: String) async throws -> Double? {
        var components = URLComponents(url: clobBase.appendingPathComponent("last-trade-price"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "token_id", value: tokenId)
        ]
        guard let url = components?.url else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(LastTradePriceResponse.self, from: data)
        return Double(response.price)
    }
}

struct OrderBookResponse: Decodable {
    let bids: [OrderLevelRaw]?
    let asks: [OrderLevelRaw]?
    let buys: [OrderLevelRaw]?
    let sells: [OrderLevelRaw]?
}

struct PriceHistoryResponse: Decodable {
    let history: [PriceHistoryPoint]
}

struct PriceHistoryPoint: Decodable {
    let timestamp: TimeInterval
    let price: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([Double].self), array.count >= 2 {
            timestamp = array[0]
            price = array[1]
            return
        }
        if let array = try? container.decode([String].self), array.count >= 2 {
            timestamp = TimeInterval(array[0]) ?? 0
            price = Double(array[1]) ?? 0
            return
        }
        if let object = try? container.decode([String: Double].self) {
            if let t = object["t"], let p = object["p"] {
                timestamp = t
                price = p
                return
            }
            timestamp = object["timestamp"] ?? object["time"] ?? 0
            price = object["price"] ?? 0
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        if let time = try? keyed.decode(TimeInterval.self, forKey: .t) {
            timestamp = time
        } else {
            timestamp = (try? keyed.decode(TimeInterval.self, forKey: .timestamp)) ?? 0
        }
        if let value = try? keyed.decode(Double.self, forKey: .p) {
            price = value
        } else {
            price = (try? keyed.decode(Double.self, forKey: .price)) ?? 0
        }
    }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case price
        case t
        case p
    }
}

struct LastTradePriceResponse: Decodable {
    let price: String
}
