//
//  GrainSeeder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The seed of every `grain` operation in an output frame is that frame's number, shared by every list nested in it.
struct GrainSeeder: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // Frame k holds `[k / fps, (k + 1) / fps)` with its ends computed as `Double(k) / fps`, as evaluation computes
    // frame k's time, so frame k drawn at its own time has seed k.
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
