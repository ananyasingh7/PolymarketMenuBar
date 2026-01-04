import Foundation

@MainActor
final class MarketWebSocket: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var orderBook: OrderBookSnapshot = OrderBookSnapshot(bids: [], asks: [], lastUpdated: Date())
    @Published var lastTradePrice: Double? = nil

    private var task: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var bidMap: [Double: Double] = [:]
    private var askMap: [Double: Double] = [:]
    private let decoder = JSONDecoder()

    func connect(tokenId: String) {
        disconnect()
        guard let url = URL(string: "wss://ws-subscriptions-clob.polymarket.com/ws/market") else { return }
        let session = URLSession(configuration: .default)
        task = session.webSocketTask(with: url)
        task?.resume()
        sendSubscribe(tokenId: tokenId)
        startPing()
        listen()
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
        bidMap.removeAll()
        askMap.removeAll()
        orderBook = OrderBookSnapshot(bids: [], asks: [], lastUpdated: Date())
        lastTradePrice = nil
    }

    private func sendSubscribe(tokenId: String) {
        let message = MarketSubscribeMessage(type: "market", assets_ids: [tokenId])
        guard let data = try? JSONEncoder().encode(message) else { return }
        task?.send(.data(data)) { [weak self] error in
            Task { @MainActor in
                if error == nil {
                    self?.isConnected = true
                } else {
                    self?.isConnected = false
                }
            }
        }
    }

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.task?.send(.string("PING")) { _ in }
            }
        }
    }

    private func listen() {
        Task { [weak self] in
            guard let self else { return }
            while let task = self.task {
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        self.handlePayload(text.data(using: .utf8))
                    case .data(let data):
                        self.handlePayload(data)
                    @unknown default:
                        break
                    }
                } catch {
                    self.isConnected = false
                    break
                }
            }
        }
    }

    private func handlePayload(_ data: Data?) {
        guard let data else { return }
        guard let message = try? decoder.decode(MarketWSMessage.self, from: data) else { return }
        switch message.eventType {
        case "book":
            handleBook(message)
        case "price_change":
            handlePriceChange(message)
        case "last_trade_price":
            if let priceText = message.price, let price = Double(priceText) {
                lastTradePrice = price
            }
        default:
            break
        }
    }

    private func handleBook(_ message: MarketWSMessage) {
        bidMap.removeAll()
        askMap.removeAll()
        let bids = message.buys ?? message.bids ?? []
        let asks = message.sells ?? message.asks ?? []
        for level in bids {
            if let price = Double(level.price), let size = Double(level.size) {
                bidMap[price] = size
            }
        }
        for level in asks {
            if let price = Double(level.price), let size = Double(level.size) {
                askMap[price] = size
            }
        }
        publishBook()
    }

    private func handlePriceChange(_ message: MarketWSMessage) {
        let changes = message.changes ?? message.priceChanges ?? []
        for change in changes {
            guard let price = Double(change.price), let size = Double(change.size) else { continue }
            if change.side.uppercased() == "BUY" {
                if size == 0 {
                    bidMap.removeValue(forKey: price)
                } else {
                    bidMap[price] = size
                }
            } else if change.side.uppercased() == "SELL" {
                if size == 0 {
                    askMap.removeValue(forKey: price)
                } else {
                    askMap[price] = size
                }
            }
        }
        publishBook()
    }

    private func publishBook() {
        let bids = bidMap.map { OrderLevel(price: $0.key, size: $0.value) }
            .sorted { $0.price > $1.price }
        let asks = askMap.map { OrderLevel(price: $0.key, size: $0.value) }
            .sorted { $0.price < $1.price }
        orderBook = OrderBookSnapshot(bids: bids, asks: asks, lastUpdated: Date())
    }
}

struct MarketSubscribeMessage: Encodable {
    let type: String
    let assets_ids: [String]
}
