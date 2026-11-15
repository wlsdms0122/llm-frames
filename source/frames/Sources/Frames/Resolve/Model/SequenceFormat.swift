//
//  SequenceFormat.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The format keys the time plan reads. Each is nil when the document leaves it to its default.
struct SequenceFormat: Equatable, Sendable {
    // MARK: - Property
    private static let frameRates: [Double] = [24, 25, 30, 50, 60]
    private static let defaultFrameRate: Double = 30

    let fps: Double?

    // MARK: - Initializer
    init(fps: Double? = nil) {
        self.fps = fps
    }

    // MARK: - Public
    // `storyline` is the media of the storyline clips, in order.
    func frameRate(of storyline: [ResolvedMedia]) -> Double {
        fps ?? defaultFrameRate(of: storyline)
    }

    // MARK: - Private
    // The nominal rate of the first video on the storyline, to the nearest common rate.
    private func defaultFrameRate(of storyline: [ResolvedMedia]) -> Double {
        guard let rate = storyline.first(where: { $0.kind == .video })?.fps else { return Self.defaultFrameRate }

        // The rates ascend and only a nearer one replaces the nearest so far, so a tie keeps the lower.
        return Self.frameRates.reduce(Self.frameRates[0]) { nearest, candidate in
            abs(candidate - rate) < abs(nearest - rate) ? candidate : nearest
        }
    }
}
