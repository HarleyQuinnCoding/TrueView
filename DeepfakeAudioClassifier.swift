import CoreML

class DeepfakeAudioClassifier {
    private let model: TrueViewAudioClassifier  // ← check generated class name
    
    init?() {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        guard let m = try? TrueViewAudioClassifier(configuration: config) else { return nil }
        model = m
    }

    func classify(samples: [Float]) -> (Bool, Double)? {
        guard samples.count == 64000,
              let array = try? MLMultiArray(shape: [1, 64000] as [NSNumber], dataType: .float32) else { return nil }
        for (i, s) in samples.enumerated() { array[[0, i] as [NSNumber]] = NSNumber(value: s) }
        guard let out = try? model.prediction(waveform: array) else { return nil }
        let label = out.classLabel.uppercased()
        // CALIBRATION (Oct 11, verified on-device): this model's label words are
        // swapped vs ground truth — a real human voice scores "fake" at 99% and a
        // known AI voice scores "real" at 80%. Interpret inverted so verdicts match
        // reality. Confidence still reflects the model's own certainty.
        let isFake = label == "REAL"

        // Softmax: turns the model's raw scores into a true 0–100% probability
        let vals = Array(out.classLabel_probs.values)
        let exps = vals.map { exp($0) }
        let total = exps.reduce(0, +)
        let raw = out.classLabel_probs[out.classLabel] ?? 0.0
        let confidence = total > 0 ? min(max(exp(raw) / total, 0), 1) : 0.0
        return (isFake, confidence)
    }
}
