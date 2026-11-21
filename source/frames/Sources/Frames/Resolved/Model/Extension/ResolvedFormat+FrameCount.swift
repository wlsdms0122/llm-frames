//
//  ResolvedFormat+FrameCount.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The output frames of a sequence: frame k is drawn at k / fps for every k whose time, measured to the microsecond, is
// before `duration`, and frame 0 always, so the output lasts `duration` to within one frame and its last frame is
// inside the sequence.
extension ResolvedFormat {
    // MARK: - Property
    var frameCount: Int {
        let end = duration.roundedTime
        var count = 1
        while frameTime(count).roundedTime < end {
            count += 1
        }

        return count
    }

    // MARK: - Initializer
    // MARK: - Public
    func frameTime(_ index: Int) -> Double {
        Double(index) / fps
    }

    // MARK: - Private
}
