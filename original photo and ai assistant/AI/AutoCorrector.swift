//
//  AutoCorrector.swift
//  AI Camera Coach
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

final class AutoCorrector: Sendable {

    enum AlternativeStyle: String, CaseIterable, Identifiable, Sendable {
        case natural, balanced, cinematic
        var id: String { rawValue }
        var title: String {
            switch self {
            case .natural: return "Natural"
            case .balanced: return "Balanced"
            case .cinematic: return "Cinematic"
            }
        }
    }

    private let context: CIContext

    init() {
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    func apply(to image: UIImage, mode: CaptureMode) -> UIImage {
        guard let cg = image.cgImage else { return image }
        var ci = CIImage(cgImage: cg)

        for filter in ci.autoAdjustmentFilters() {
            filter.setValue(ci, forKey: kCIInputImageKey)
            if let out = filter.outputImage {
                ci = out
            }
        }

        switch mode {
        case .smart, .family, .child:
            ci = adjust(ci, saturation: 1.05, contrast: 1.04, brightness: 0.0)
        case .pet:
            ci = adjust(ci, saturation: 1.08, contrast: 1.06, brightness: 0.0)
        case .travel:
            ci = adjust(ci, saturation: 1.12, contrast: 1.08, brightness: 0.0)
        }

        return render(ci, base: image)
    }

    func alternative(image: UIImage, style: AlternativeStyle) -> UIImage {
        guard let cg = image.cgImage else { return image }
        var ci = CIImage(cgImage: cg)
        switch style {
        case .natural:
            ci = adjust(ci, saturation: 0.98, contrast: 1.00, brightness: 0.0)
        case .balanced:
            ci = adjust(ci, saturation: 1.08, contrast: 1.06, brightness: 0.0)
        case .cinematic:
            ci = adjust(ci, saturation: 0.90, contrast: 1.18, brightness: -0.02)
        }
        return render(ci, base: image)
    }

    private func adjust(_ image: CIImage,
                        saturation: Float,
                        contrast: Float,
                        brightness: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = saturation
        filter.contrast = contrast
        filter.brightness = brightness
        return filter.outputImage ?? image
    }

    private func render(_ ci: CIImage, base: UIImage) -> UIImage {
        guard let outCG = context.createCGImage(ci, from: ci.extent) else { return base }
        return UIImage(cgImage: outCG, scale: base.scale, orientation: base.imageOrientation)
    }
}
