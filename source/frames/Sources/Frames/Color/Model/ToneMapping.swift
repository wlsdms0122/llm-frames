//
//  ToneMapping.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

import Foundation

// The EETF of BT.2390 on max(R, G, B) of display light, RGB scaled by the ratio it gives so the hue is kept: from a
// source peak to a target peak, the peak of the sequence's colour space, with a source and a target black of 0. A
// source at or below the target peak is kept as it is.
package struct ToneMapping: Equatable, Sendable {
    // MARK: - Property
    private static let quantizer = PerceptualQuantizer()

    package let sourcePeak: Double
    package let targetPeak: Double
    package let sourceBlack = 0.0
    package let targetBlack = 0.0

    // MARK: - Initializer
    // Both peaks in cd/m², each at most 10000.
    package init(
        sourcePeak: Double,
        targetPeak: Double
    ) {
        self.sourcePeak = min(sourcePeak, PerceptualQuantizer.peakLuminance)
        self.targetPeak = min(targetPeak, PerceptualQuantizer.peakLuminance)
    }

    // The source peak of an HDR picture in `space`: for PQ the maximum luminance of its mastering display, or 1000
    // cd/m² where it has none, and for HLG 1000 cd/m², its OOTF's peak.
    package init(
        space: ColorSpace,
        masteringDisplayPeak: Double?,
        targetPeak: Double
    ) {
        switch space {
        case .rec2100PQ:
            self.init(sourcePeak: masteringDisplayPeak ?? HybridLogGamma.nominalPeakLuminance, targetPeak: targetPeak)

        default:
            self.init(sourcePeak: HybridLogGamma.nominalPeakLuminance, targetPeak: targetPeak)
        }
    }

    // MARK: - Public
    // Display light in cd/m² on BT.2020 primaries, tone mapped; 0 where its largest channel is 0 or less.
    package func mapped(_ displayLight: RGB) -> RGB {
        let largest = displayLight.maximum
        guard largest > 0 else { return RGB(red: 0, green: 0, blue: 0) }

        return displayLight.scaled(by: mapped(largest) / largest)
    }

    // MARK: - Private
    private func mapped(_ luminance: Double) -> Double {
        let quantizer = Self.quantizer
        let sourceBlack = quantizer.encoded(displayLight: sourceBlack)
        let range = quantizer.encoded(displayLight: sourcePeak) - sourceBlack
        let normalized = { (light: Double) in (quantizer.encoded(displayLight: light) - sourceBlack) / range }

        let e1 = min(max(normalized(luminance), 0), 1)
        let minimumLuminance = normalized(targetBlack)
        let maximumLuminance = normalized(targetPeak)
        let kneeStart = 1.5 * maximumLuminance - 0.5

        let e2: Double
        if sourcePeak <= targetPeak || e1 < kneeStart {
            e2 = e1
        } else {
            let t = (e1 - kneeStart) / (1 - kneeStart)
            let t2 = t * t
            let t3 = t2 * t
            e2 = (2 * t3 - 3 * t2 + 1) * kneeStart + (t3 - 2 * t2 + t) * (1 - kneeStart) + (-2 * t3 + 3 * t2)
                * maximumLuminance
        }
        let e3 = e2 + minimumLuminance * pow(1 - e2, 4)
        let e4 = e3 * range + sourceBlack

        return quantizer.displayLight(encoded: e4)
    }
}
