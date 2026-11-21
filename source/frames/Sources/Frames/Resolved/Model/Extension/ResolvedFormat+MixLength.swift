//
//  ResolvedFormat+MixLength.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The mix plan's length N: the samples per channel at the mix's sample rate that the output frames last, at the rate
// frames presents them.
extension ResolvedFormat {
    // MARK: - Property
    var mixLength: Int {
        FrameRate(fps: fps).samples(ofFrames: frameCount, sampleRate: MixPlan.sampleRate)
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
