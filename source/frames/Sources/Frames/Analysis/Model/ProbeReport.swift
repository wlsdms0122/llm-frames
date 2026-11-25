//
//  ProbeReport.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `probe` prints about a medium (FRAMES-23): its kind (`image`, `page`, `video`, `audio` or `imageSequence`), its
// picture's size, its duration and nominal frame rate, whether its picture carries alpha, its picture's colour facts,
// its first sound track's format, and the page count of a PDF. A value the medium does not have is nil: the size and
// colour of sound, the duration and rate of a still, the duration and rate of an image sequence, which the document's
// `fps` gives, and the page count of every medium that is no PDF. A PDF of more than one page probed with no page named
// is no one medium, so it gives only its page count.
package struct ProbeReport: Equatable, Sendable {
    // MARK: - Property
    package let kind: String?
    package let size: Size?
    package let duration: Double?
    package let fps: Double?
    package let hasAlpha: Bool?
    package let colorSpace: ProbedColorSpace?
    package let sound: ProbedSound?
    package let pageCount: Int?

    // MARK: - Initializer
    init(
        kind: String?,
        size: Size?,
        duration: Double?,
        fps: Double?,
        hasAlpha: Bool?,
        colorSpace: ProbedColorSpace?,
        sound: ProbedSound?,
        pageCount: Int? = nil
    ) {
        self.kind = kind
        self.size = size
        self.duration = duration
        self.fps = fps
        self.hasAlpha = hasAlpha
        self.colorSpace = colorSpace
        self.sound = sound
        self.pageCount = pageCount
    }

    init(_ probed: ProbedMedia) {
        self.init(
            kind: probed.kind.rawValue,
            size: probed.size,
            duration: probed.kind.isStill ? nil : probed.duration,
            fps: probed.fps,
            hasAlpha: probed.hasAlpha,
            colorSpace: probed.colorSpace,
            sound: probed.sound
        )
    }

    init(_ sequence: ProbedImageSequence) {
        self.init(
            kind: "imageSequence",
            size: sequence.size,
            duration: nil,
            fps: nil,
            hasAlpha: sequence.hasAlpha,
            colorSpace: sequence.colorSpace,
            sound: nil
        )
    }

    // A page of a PDF: its size in points, with alpha, and the colour space of its untagged colour, `srgb`, with no
    // bits per channel, since a page has no pixels of its own, and not HDR.
    init(_ page: ProbedPage) {
        self.init(
            kind: MediaKind.page.rawValue,
            size: page.size,
            duration: nil,
            fps: nil,
            hasAlpha: true,
            colorSpace: ProbedColorSpace(
                conversion: .identity,
                primaries: 1,
                transfer: 13,
                matrix: nil,
                bitDepth: nil,
                isHighDynamicRange: false
            ),
            sound: nil,
            pageCount: page.pageCount
        )
    }

    // A PDF of more than one page with no page named: only its page count.
    init(pageCount: Int) {
        self.init(
            kind: nil,
            size: nil,
            duration: nil,
            fps: nil,
            hasAlpha: nil,
            colorSpace: nil,
            sound: nil,
            pageCount: pageCount
        )
    }

    // MARK: - Public
    // MARK: - Private
}
