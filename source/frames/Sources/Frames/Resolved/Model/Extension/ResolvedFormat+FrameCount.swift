//
//  ResolvedFormat+FrameCount.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The output frames of a sequence: frame k is drawn at k / fps for every k whose time lies more than a microsecond
// before `duration`, and frame 0 always, so the output lasts `duration` to within one frame, its last frame is inside
// the sequence, and floating point noise in `duration` adds no frame.
extension ResolvedFormat {
    // MARK: - Property
    private static let noise = 1e-6

    var frameCount: Int {
        let end = duration - Self.noise
        var count = max(Int((end * fps).rounded(.up)), 1)

        // `end * fps` is rounded, so the count is moved to where frame times, measured as evaluation measures them,
        // cross the end.
        while count > 1 && frameTime(count - 1) >= end {
            count -= 1
        }
        while frameTime(count) < end {
            count += 1
        }

        return count
    }

    // How long the output plays: its frames, each lasting 1 / fps.
    var renderedDuration: Double {
        frameTime(frameCount)
    }

    // MARK: - Initializer
    // MARK: - Public
    func frameTime(_ index: Int) -> Double {
        Double(index) / fps
    }

    // MARK: - Private
}
