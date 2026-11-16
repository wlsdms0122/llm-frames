//
//  ClipPlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A connected or sequence clip on the sequence clock. `window` is where its `at` puts it, and `visible` is the part of
// the window it is seen or heard in. `storyline` is the index of the storyline clip a connected clip belongs to, and
// `clock` maps its instants to sequence time. `instant` is where its areas take effect: the start of its window, or its
// storyline clip's `in` when it has no `at`. `keyframes` are in sequence time. `labelAnimation` is a shape's label's
// own animation, none without a label.
struct ClipPlan: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let kind: ClipKind
    let storyline: Int?
    let isParented: Bool
    let lane: Int?
    let clock: TimeMap
    let window: TimeRange
    let visible: TimeRange
    let instant: Double
    let animation: AnimationPlan
    let labelAnimation: AnimationPlan
    let media: MediaPlan?
    let timing: MediaTiming?
    let keyframes: [KeyframeInstant]

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        kind: ClipKind,
        storyline: Int?,
        isParented: Bool,
        lane: Int?,
        clock: TimeMap,
        window: TimeRange,
        visible: TimeRange,
        instant: Double,
        animation: AnimationPlan,
        labelAnimation: AnimationPlan = .none,
        media: MediaPlan?,
        timing: MediaTiming?,
        keyframes: [KeyframeInstant]
    ) {
        self.place = place
        self.id = id
        self.kind = kind
        self.storyline = storyline
        self.isParented = isParented
        self.lane = lane
        self.clock = clock
        self.window = window
        self.visible = visible
        self.instant = instant
        self.animation = animation
        self.labelAnimation = labelAnimation
        self.media = media
        self.timing = timing
        self.keyframes = keyframes
    }

    // MARK: - Public
    func narrowed(to visible: TimeRange) -> ClipPlan {
        ClipPlan(
            place: place,
            id: id,
            kind: kind,
            storyline: storyline,
            isParented: isParented,
            lane: lane,
            clock: clock,
            window: window,
            visible: visible,
            instant: instant,
            animation: animation,
            labelAnimation: labelAnimation,
            media: media,
            timing: timing,
            keyframes: keyframes
        )
    }

    // MARK: - Private
}
