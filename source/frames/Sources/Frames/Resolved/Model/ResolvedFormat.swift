//
//  ResolvedFormat.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The output frame of a sequence in output pixels, its frame rate and duration (the sequence end), the colour behind
// everything, how storyline crops were conformed to it, the colour space its output is in, the mastering peak of a
// `rec2100-pq` sequence in cd/m² (nil in any other space), and the form its sums of colours are taken in.
struct ResolvedFormat: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let fps: Double
    let duration: Double
    let background: Color
    let conform: Conform
    let colorSpace: ColorSpace
    let peak: Double?
    let compositing: Compositing

    var frame: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // The sequence's peak in cd/m²: its `peak` for `rec2100-pq`, and its colour space's otherwise.
    var peakLuminance: Double {
        peak ?? colorSpace.peakLuminance
    }

    // How its output is encoded, clipped to its colour space's gamut and its peak.
    var output: ColorConversion {
        ColorConversion(space: colorSpace, peak: peakLuminance)
    }

    // MARK: - Initializer
    init(
        size: Size,
        fps: Double,
        duration: Double,
        background: Color,
        conform: Conform,
        colorSpace: ColorSpace = .srgb,
        peak: Double? = nil,
        compositing: Compositing = .encoded
    ) {
        self.size = size
        self.fps = fps
        self.duration = duration
        self.background = background
        self.conform = conform
        self.colorSpace = colorSpace
        self.peak = peak
        self.compositing = compositing
    }

    // MARK: - Public
    // MARK: - Private
}
