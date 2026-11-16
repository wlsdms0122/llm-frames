//
//  GrainSeeder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The seed of every `grain` operation in an output frame: the number of that frame, so grain belongs to the output
// frame and every list nested in it shares it.
struct GrainSeeder: Sendable {
    // MARK: - Property
    // An image or layout has one display list, and its grain one seed.
    static let pictureSeed = 0

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // The number of the sequence frame whose interval `[k / fps, (k + 1) / fps)` holds the time, so frame k, drawn at
    // k / fps, has seed k. The interval ends are measured as evaluation measures frame k's time, `Double(k) / fps`.
    func seed(
        at time: Double,
        fps: Double
    ) -> Int {
        let frame = Int((time * fps).rounded(.down))

        if Double(frame + 1) / fps <= time {
            return frame + 1
        }

        if Double(frame) / fps > time {
            return frame - 1
        }

        return frame
    }

    // MARK: - Private
}
