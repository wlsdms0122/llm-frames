//
//  SequenceFormat.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The format keys resolve reads, the shutter's by its keys. Each is nil when the document leaves it to its default.
struct SequenceFormat: Equatable, Sendable {
    // MARK: - Property
    private static let frameRates: [Double] = [24, 25, 30, 50, 60]
    private static let defaultFrameRate: Double = 30

    let fps: Double?
    let size: FormatSize?
    let conform: Conform?
    let background: String?
    let colorSpace: ColorSpace?
    let peak: Double?
    let compositing: Compositing?
    let shutterAngle: Double?
    let shutterPhase: Double?
    let samplesPerFrame: Int?

    // MARK: - Initializer
    init(
        fps: Double? = nil,
        size: FormatSize? = nil,
        conform: Conform? = nil,
        background: String? = nil,
        colorSpace: ColorSpace? = nil,
        peak: Double? = nil,
        compositing: Compositing? = nil,
        shutterAngle: Double? = nil,
        shutterPhase: Double? = nil,
        samplesPerFrame: Int? = nil
    ) {
        self.fps = fps
        self.size = size
        self.conform = conform
        self.background = background
        self.colorSpace = colorSpace
        self.peak = peak
        self.compositing = compositing
        self.shutterAngle = shutterAngle
        self.shutterPhase = shutterPhase
        self.samplesPerFrame = samplesPerFrame
    }

    // MARK: - Public
    // `storyline` is the media of the storyline clips, in order.
    func frameRate(of storyline: [MediaPlan]) -> Double {
        fps ?? defaultFrameRate(of: storyline)
    }

    // MARK: - Private
    // The nominal rate of the first video on the storyline, to the nearest common rate.
    private func defaultFrameRate(of storyline: [MediaPlan]) -> Double {
        guard
            let video = storyline.first(where: { $0.kind == .video }),
            case let .file(file) = video.source,
            let rate = file.fps
        else {
            return Self.defaultFrameRate
        }

        // The rates ascend and only a nearer one replaces the nearest so far, so a tie keeps the lower.
        return Self.frameRates.reduce(Self.frameRates[0]) { nearest, candidate in
            abs(candidate - rate) < abs(nearest - rate) ? candidate : nearest
        }
    }
}
