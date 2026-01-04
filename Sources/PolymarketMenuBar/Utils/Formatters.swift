import Foundation

func formatPercent(_ value: Double) -> String {
    let clamped = min(max(value, 0), 1)
    return String(format: "%.1f%%", clamped * 100)
}

func moneylineOdds(probability: Double) -> String {
    guard probability > 0, probability < 1 else { return "--" }
    let odds: Double
    if probability >= 0.5 {
        odds = -((probability / (1 - probability)) * 100)
    } else {
        odds = ((1 - probability) / probability) * 100
    }
    let rounded = Int(odds.rounded())
    return rounded > 0 ? "+\(rounded)" : "\(rounded)"
}

func formatPrice(_ value: Double) -> String {
    String(format: "%.4f", value)
}
