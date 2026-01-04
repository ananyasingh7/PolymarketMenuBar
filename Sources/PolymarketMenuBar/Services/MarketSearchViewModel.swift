import Foundation

@MainActor
final class MarketSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var markets: [MarketSummary] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date? = nil
    @Published var errorMessage: String? = nil

    private let api = PolymarketAPI()
    private var searchTask: Task<Void, Never>?

    func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            await self.loadMarkets()
        }
    }

    func loadMarkets() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            lastUpdated = Date()
        }

        do {
            let results = try await api.fetchMarkets(query: query)
            markets = results
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
