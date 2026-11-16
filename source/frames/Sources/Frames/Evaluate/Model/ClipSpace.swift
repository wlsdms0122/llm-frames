//
//  ClipSpace.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where a clip is composited at one instant, and the coordinates its items are drawn in. An unparented clip is drawn in
// output pixels. A parented clip is drawn in its unit's coordinates, the content rect with its origin at its top left,
// and its positions and areas, in the media pixels of the storyline entry's picture, are mapped into the unit through
// that entry's conformed crop at the instant, so they follow the crop. `room` is what a shape without an area covers
// and what a dim darkens: the unit for a parented clip, the content rect for an unparented connected clip, and the
// output frame for a sequence clip.
struct ClipSpace: Sendable {
    // MARK: - Property
    let room: Rectangle

    // The storyline entry a parented clip is composited with, and its conformed crop at the instant.
    private let parent: ResolvedStorylineClip?
    private let crop: Rectangle?
    private let conformer = CropConformer()

    // MARK: - Initializer
    // An unparented clip's space, in output pixels.
    init(room: Rectangle) {
        self.room = room
        self.parent = nil
        self.crop = nil
    }

    // A parented clip's space, the unit of `entry` the size of the content rect.
    init(
        parent entry: ResolvedStorylineClip,
        unit: Rectangle,
        at time: Double
    ) {
        self.room = unit
        self.parent = entry
        self.crop = entry.crop(at: time)
    }

    // MARK: - Public
    // A clip's area at the time, its keyframes carried by its track when it is tracked.
    func area(
        of keyframes: [Keyframe<Rectangle>],
        track: ResolvedTrack?,
        at time: Double
    ) -> Rectangle {
        guard let parent, let crop else { return value(of: keyframes, at: time) }

        let area = track?.area(of: keyframes, on: parent, at: time) ?? value(of: keyframes, at: time)
        return conformer.output(of: area, crop: crop, content: room)
    }

    // The top left of a box clip's box at the time. A parented clip's anchor point, `position + anchor` in media
    // pixels and carried by its track when it is tracked, is mapped into the unit, and the box keeps its size in
    // output pixels around it.
    func position(
        of box: ResolvedBox,
        track: ResolvedTrack?,
        at time: Double
    ) -> Point {
        guard let parent, let crop else { return value(of: box.position, at: time) }

        let anchors = box.position.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: Point(x: keyframe.value.x + box.anchor.x, y: keyframe.value.y + box.anchor.y),
                ease: keyframe.ease
            )
        }
        let anchor = track?.point(of: anchors, on: parent, at: time) ?? value(of: anchors, at: time)
        let scale = room.width / crop.width

        return Point(
            x: room.x + (anchor.x - crop.x) * scale - box.anchor.x,
            y: room.y + (anchor.y - crop.y) * scale - box.anchor.y
        )
    }

    // MARK: - Private
    private func value<Value: Interpolable>(
        of keyframes: [Keyframe<Value>],
        at time: Double
    ) -> Value {
        // A property holds at least one keyframe, so the keyframes always give one.
        KeyframeTrack(keyframes: keyframes).value(at: time) ?? keyframes[0].value
    }
}
