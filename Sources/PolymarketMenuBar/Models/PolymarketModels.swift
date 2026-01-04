import Foundation

struct MarketSummary: Identifiable, Hashable {
    let id: String
    let eventTitle: String
    let marketTitle: String
    let outcomes: [String]
    let outcomePrices: [Double]
    let clobTokenIds: [String]
    let conditionId: String?

    var yesTokenId: String? {
        clobTokenIds.first
    }

    var noTokenId: String? {
        clobTokenIds.count > 1 ? clobTokenIds[1] : nil
    }

    var yesPrice: Double? {
        outcomePrices.first
    }

    var noPrice: Double? {
        outcomePrices.count > 1 ? outcomePrices[1] : nil
    }
}

struct OrderLevel: Identifiable, Hashable {
    let id = UUID()
    let price: Double
    let size: Double
}

struct OrderBookSnapshot {
    var bids: [OrderLevel]
    var asks: [OrderLevel]
    var lastUpdated: Date
}

struct PricePoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let price: Double
}

struct GammaEvent: Decodable {
    let id: String
    let title: String?
    let slug: String?
    let markets: [GammaMarket]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case slug
        case markets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = UUID().uuidString
        }
        title = try? container.decode(String.self, forKey: .title)
        slug = try? container.decode(String.self, forKey: .slug)
        markets = (try? container.decode([GammaMarket].self, forKey: .markets)) ?? []
    }
}

struct GammaMarket: Decodable {
    let id: String
    let question: String?
    let title: String?
    let slug: String?
    let outcomes: FlexibleStringArray?
    let outcomePrices: FlexibleDoubleArray?
    let clobTokenIds: FlexibleStringArray?
    let conditionId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case question
        case title
        case slug
        case outcomes
        case outcomePrices
        case clobTokenIds
        case conditionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = UUID().uuidString
        }
        question = try? container.decode(String.self, forKey: .question)
        title = try? container.decode(String.self, forKey: .title)
        slug = try? container.decode(String.self, forKey: .slug)
        outcomes = try? container.decode(FlexibleStringArray.self, forKey: .outcomes)
        outcomePrices = try? container.decode(FlexibleDoubleArray.self, forKey: .outcomePrices)
        clobTokenIds = try? container.decode(FlexibleStringArray.self, forKey: .clobTokenIds)
        conditionId = try? container.decode(String.self, forKey: .conditionId)
    }
}

struct GammaSearchResponse: Decodable {
    let events: [GammaEvent]
}

struct OrderLevelRaw: Decodable {
    let price: String
    let size: String
}

struct PriceChange: Decodable {
    let price: String
    let side: String
    let size: String
}

struct MarketWSMessage: Decodable {
    let eventType: String
    let assetId: String?
    let buys: [OrderLevelRaw]?
    let sells: [OrderLevelRaw]?
    let bids: [OrderLevelRaw]?
    let asks: [OrderLevelRaw]?
    let changes: [PriceChange]?
    let priceChanges: [PriceChange]?
    let price: String?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case assetId = "asset_id"
        case buys
        case sells
        case bids
        case asks
        case changes
        case priceChanges = "price_changes"
        case price
    }
}

struct FlexibleStringArray: Decodable {
    let values: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            values = array
            return
        }
        if let stringValue = try? container.decode(String.self) {
            if let data = stringValue.data(using: .utf8),
               let array = try? JSONDecoder().decode([String].self, from: data) {
                values = array
                return
            }
        }
        values = []
    }
}

struct FlexibleDoubleArray: Decodable {
    let values: [Double]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([Double].self) {
            values = array
            return
        }
        if let stringArray = try? container.decode([String].self) {
            values = stringArray.compactMap { Double($0) }
            return
        }
        if let stringValue = try? container.decode(String.self) {
            if let data = stringValue.data(using: .utf8) {
                if let array = try? JSONDecoder().decode([Double].self, from: data) {
                    values = array
                    return
                }
                if let array = try? JSONDecoder().decode([String].self, from: data) {
                    values = array.compactMap { Double($0) }
                    return
                }
            }
        }
        values = []
    }
}
