import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MarketSearchViewModel()
    @State private var selection: MarketSummary?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Search markets", text: $viewModel.query)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        viewModel.scheduleSearch(immediate: true)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                }

                if viewModel.isLoading {
                    ProgressView()
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                }

                List(viewModel.markets, selection: $selection) { market in
                    MarketRowView(market: market)
                        .tag(market)
                }
                .listStyle(.inset)

                if let updated = viewModel.lastUpdated {
                    Text("Updated \(updated.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(minWidth: 320)
            .onAppear {
                if viewModel.markets.isEmpty {
                    viewModel.scheduleSearch(immediate: true)
                }
            }
            .onChange(of: viewModel.query) { _ in
                viewModel.scheduleSearch()
            }
        } detail: {
            if let selection {
                MarketDetailView(market: selection)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 36))
                    Text("Choose a market")
                        .font(.headline)
                    Text("Search on the left to load live prices, charts, and the order book.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 640)
    }
}
