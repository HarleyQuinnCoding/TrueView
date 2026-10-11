import SwiftUI

struct Verdict {
    let isFake: Bool
    let confidence: Double   // 0.0 – 1.0
    let modality: String     // "photo" or "voice"

    var title: String { isFake ? "Blight Touched" : "Bloom Blessed" }
    var subtitle: String {
        isFake
          ? "This \(modality) carries the mark of fabrication."
          : "This \(modality) is genuine and untouched by illusion."
    }
    var primary: Color { isFake ? Color(red: 0.55, green: 0.30, blue: 0.85)
                                : Color(red: 0.05, green: 0.35, blue: 0.22) }
    var glow: Color    { isFake ? Color(red: 0.75, green: 0.55, blue: 1.0)
                                : Color(red: 0.95, green: 0.80, blue: 0.40) }
}
