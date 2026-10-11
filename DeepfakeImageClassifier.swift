import UIKit
import CoreML

class DeepfakeImageClassifier {
    private let model: TrueViewImageClassifier  // ← check generated class name

    init?() {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        guard let m = try? TrueViewImageClassifier(configuration: config) else { return nil }
        model = m
    }


    /// Returns (isFake, confidence). Never trusts label *index* —
    /// models name labels differently (dima806: REAL/FAKE, umm-maybe:
    /// HUMAN/ARTIFICIAL, king1oo1: Real/Fake, Cr2do: real/ai_generated).
    /// Match the word, not the number.
    func classify(_ image: UIImage) -> (Bool, Double)? {
        guard let input = preprocessForTrueView(image) else { return nil }
        guard let out = try? model.prediction(image: input) else { return nil }
        // Print once during dev to confirm the real label strings:
        // print(out.classLabel, out.classLabelProbs)
        let label = out.classLabel.uppercased()
        let isFake = label.contains("FAKE") || label.contains("ARTIFICIAL")
            || label.contains("AI_GENERATED")
        // Softmax: turns the model's raw scores into a true 0–100% probability
        let vals = Array(out.classLabel_probs.values)
        let exps = vals.map { exp($0) }
        let total = exps.reduce(0, +)
        let raw = out.classLabel_probs[out.classLabel] ?? 0.0
        let confidence = total > 0 ? min(max(exp(raw) / total, 0), 1) : 0.0
        return (isFake, confidence)
    }
}
