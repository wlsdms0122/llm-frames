//
//  InterpolatingFilter.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

import Accelerate

// The 48-tap interpolating filter of ITU-R BS.1770-5 Annex 2 as four phases of 12 taps, u_p[m] = Σ h_p[k] x[m - k]
// over k from 0 to 11. u_p[n + 6] is the sound at n + (2p + 1)/8, between samples n and n + 1: the 48 taps are
// symmetric about tap 23.5, so every frequency is delayed by the same 23.5 oversampled steps. It is computed in
// floating point, so the Annex's attenuation before the filter and its gain after it, which give headroom to integer
// arithmetic, are left out.
package struct InterpolatingFilter: Sendable {
    // MARK: - Property
    package static let tapCount = 12

    // h_p[k] for p from 0 to 3, h_p[0] first, as the Annex gives them.
    package static let phases: [[Float]] = [
        [
            0.0017089843750, 0.0109863281250, -0.0196533203125, 0.0332031250000, -0.0594482421875, 0.1373291015625,
            0.9721679687500, -0.1022949218750, 0.0476074218750, -0.0266113281250, 0.0148925781250, -0.0083007812500
        ],
        [
            -0.0291748046875, 0.0292968750000, -0.0517578125000, 0.0891113281250, -0.1665039062500, 0.4650878906250,
            0.7797851562500, -0.2003173828125, 0.1015625000000, -0.0582275390625, 0.0330810546875, -0.0189208984375
        ],
        [
            -0.0189208984375, 0.0330810546875, -0.0582275390625, 0.1015625000000, -0.2003173828125, 0.7797851562500,
            0.4650878906250, -0.1665039062500, 0.0891113281250, -0.0517578125000, 0.0292968750000, -0.0291748046875
        ],
        [
            -0.0083007812500, 0.0148925781250, -0.0266113281250, 0.0476074218750, -0.1022949218750, 0.9721679687500,
            0.1373291015625, -0.0594482421875, 0.0332031250000, -0.0196533203125, 0.0109863281250, 0.0017089843750
        ]
    ]

    // Each phase with its last tap first, the order a correlation takes to give the convolution.
    private static let correlations = phases.map { Array($0.reversed()) }

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    // Writes u_p[m] for `count` values of m from some m0 into `values`, from `window`, which holds x[m0 - 11] to
    // x[m0 + count - 1] one after another.
    package func values(
        ofPhase phase: Int,
        window: UnsafePointer<Float>,
        into values: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        vDSP_conv(window, 1, Self.correlations[phase], 1, values, 1, vDSP_Length(count), vDSP_Length(Self.tapCount))
    }

    // MARK: - Private
}
