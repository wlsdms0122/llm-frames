//
//  AudioOperationProcessor.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

// Runs one audio op over a segment's sound, keeping the op's state between samples. It is made at rest at the
// segment's first sample and takes every sample after it once, in order; `sample` is the sequence sample n, at
// sequence time n / 48000, which the op's moving values are read at.
protocol AudioOperationProcessor: AnyObject {
    func process(
        _ input: StereoSample,
        atSample sample: Int
    ) -> StereoSample
}
