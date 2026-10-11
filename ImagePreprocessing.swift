import UIKit
import CoreML

func preprocessForTrueView(_ image: UIImage) -> MLMultiArray? {
    let w = 224, h = 224
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    // Explicit RGBA byte order — no guessing what the context gives us
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
                   | CGBitmapInfo.byteOrder32Big.rawValue
    guard let ctx = CGContext(data: nil, width: w, height: h,
                              bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: colorSpace, bitmapInfo: bitmapInfo),
          let cg = image.cgImage else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let px = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }

    // (x - 0.5) / 0.5 — from the model's preprocessor_config.json.
    // (PIL BICUBIC ≈ Core Graphics .high — closest available match.)
    let means: [Float] = [0.5, 0.5, 0.5]
    let stds:  [Float] = [0.5, 0.5, 0.5]
    guard let array = try? MLMultiArray(
        shape: [1, 3, h, w] as [NSNumber], dataType: .float32) else { return nil }
    for y in 0..<h {
        for x in 0..<w {
            let o = (y * w + x) * 4
            let r = Float(px[o]) / 255.0
            let g = Float(px[o+1]) / 255.0
            let b = Float(px[o+2]) / 255.0
            array[[0, 0, y, x] as [NSNumber]] = NSNumber(value: (r - means[0]) / stds[0])
            array[[0, 1, y, x] as [NSNumber]] = NSNumber(value: (g - means[1]) / stds[1])
            array[[0, 2, y, x] as [NSNumber]] = NSNumber(value: (b - means[2]) / stds[2])
        }
    }
    return array
}

