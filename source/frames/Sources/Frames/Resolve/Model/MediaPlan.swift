//
//  MediaPlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Media with what time knows of it. `reference` is the media as the document wrote it (`shorts/leak.mov`), the same on
// every machine, and nil for media written in place. `frames` is the first and last media time a picture exists at,
// nil for a still, which simply goes on, and for sound. `hasSound` says whether it plays sound: a file with a sound
// track, or a nested sequence that holds one. `colorSpace` and `isToneMapped` are how the clip that shows it reads its
// pictures: the space that overrides the file's tags, nil where they apply, and its `toneMap`, nil for a nested
// sequence, whose pictures are working values already, and for a page, which takes none.
struct MediaPlan: Equatable, Sendable {
    // MARK: - Property
    let kind: MediaKind
    let reference: String?
    let source: MediaPlanSource
    let duration: Double
    let hasSound: Bool
    let colorSpace: ColorSpace?
    let isToneMapped: Bool?

    var frames: ClosedRange<Double>? {
        switch source {
        case let .file(file):
            ClosedRange(frameTimes: file.frameTimes)

        case let .sequence(plan):
            ClosedRange(sequenceDuration: plan.duration)
        }
    }

    // MARK: - Initializer
    init(
        kind: MediaKind,
        reference: String?,
        source: MediaPlanSource,
        duration: Double,
        hasSound: Bool = false,
        colorSpace: ColorSpace? = nil,
        isToneMapped: Bool? = nil
    ) {
        self.kind = kind
        self.reference = reference
        self.source = source
        self.duration = duration
        self.hasSound = hasSound
        self.colorSpace = colorSpace
        self.isToneMapped = isToneMapped
    }

    // MARK: - Public
    // The media as `clip` reads it, its pictures tone mapped unless it says not, and a page's never, since a page is
    // not HDR. A nested sequence takes neither.
    func read(by clip: ClipMedia) -> MediaPlan {
        guard kind != .sequence else { return self }

        return MediaPlan(
            kind: kind,
            reference: reference,
            source: source,
            duration: duration,
            hasSound: hasSound,
            colorSpace: clip.colorSpace,
            isToneMapped: kind == .page ? nil : clip.isToneMapped ?? true
        )
    }
    // MARK: - Private
}
