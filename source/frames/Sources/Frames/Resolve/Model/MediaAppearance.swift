//
//  MediaAppearance.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a media clip's picture fills its box: `crop` is every crop conformed to the box by `conform`, in the clip's own
// media with keyframes in sequence time, the whole picture when none is written. `radius` rounds the box's corners,
// and `border` and `shadow` are drawn when the clip asks for them, each a timed value in output pixels, `off` for none.
struct MediaAppearance: Equatable, Sendable {
    // MARK: - Property
    let conform: Conform
    let crop: PropertyValue<Rectangle>
    let radius: TimedValue
    let border: TimedValue
    let shadow: TimedValue

    // MARK: - Initializer
    init(
        conform: Conform,
        crop: PropertyValue<Rectangle>,
        radius: TimedValue,
        border: TimedValue,
        shadow: TimedValue
    ) {
        self.conform = conform
        self.crop = crop
        self.radius = radius
        self.border = border
        self.shadow = shadow
    }

    // MARK: - Public
    // MARK: - Private
}
