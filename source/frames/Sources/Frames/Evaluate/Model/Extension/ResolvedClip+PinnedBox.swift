//
//  ResolvedClip+PinnedBox.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// Where a picture its corner pin places lies at a time, drawn flat (FRAMES-27): its box B, `[0, 0, w, h]` at the time,
// and the map from the clip's own space into B, which its masks are carried by. A title's B is its box at the time with
// its text box inside it, a media clip's is its corner pin's box with its crop stretched onto it, and a rect's or an
// ellipse's is its `width` by `height` at the time, its own space. Evaluation draws its group in B, and `timeline --at`
// carries B onto the corner pin.
extension ResolvedClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Nil for a path, which resolve never gives a corner pin and the resolved reader takes with one.
    func pinnedBox(
        of picture: ResolvedPicture,
        cornerPin: ResolvedCornerPin,
        at time: SampleTime
    ) -> (box: Rectangle, ownSpace: AffineTransform)? {
        switch picture {
        case let .title(text):
            let drawn = text.box(at: time)
            return (Rectangle(x: 0, y: 0, width: drawn.width, height: drawn.height), text.textBoxInBox(at: time))

        case let .media(media):
            let box = Rectangle(x: 0, y: 0, width: cornerPin.size.width, height: cornerPin.size.height)
            let crop = crop(of: media, at: time)
            let cropMap = AffineTransform(translation: Point(x: -crop.x, y: -crop.y))
                .concatenating(AffineTransform(mapping: Size(width: crop.width, height: crop.height), onto: box))
            return (box, cropMap)

        case let .shape(shape):
            guard case let .box(width, height, _) = shape.geometry else { return nil }

            return (Rectangle(x: 0, y: 0, width: width.value(at: time), height: height.value(at: time)), .identity)
        }
    }

    // MARK: - Private
}
