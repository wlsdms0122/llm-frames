//
//  ClipSpace.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where a clip is composited at one instant, and the coordinates its items are drawn in. `room` is what a shape without
// an area covers and what a dim darkens, and `frame` is the whole list's frame, what an adjustment without an area
// filters.
enum ClipSpace: Sendable {
    // An unparented clip, drawn in output pixels. `room` is the content rect for a connected clip and the output frame
    // for a sequence clip, and `frame` is the output frame.
    case output(room: Rectangle, frame: Rectangle)
    // A parented clip, drawn in its unit's coordinates, the content rect with its origin at its top left, which is both
    // its room and its frame. Its positions and areas, in the media pixels of the storyline entry's picture, are mapped
    // into the unit through `crop`, that entry's conformed crop at the instant, so they follow the crop.
    case parented(entry: ResolvedStorylineClip, crop: Rectangle, unit: Rectangle)

    // MARK: - Property
    var room: Rectangle {
        switch self {
        case let .output(room, _):
            room

        case let .parented(_, _, unit):
            unit
        }
    }

    var frame: Rectangle {
        switch self {
        case let .output(_, frame):
            frame

        case let .parented(_, _, unit):
            unit
        }
    }

    // MARK: - Initializer
    // A parented clip's space, the unit of `entry` the size of the content rect.
    init(
        parent entry: ResolvedStorylineClip,
        unit: Rectangle,
        at time: Double
    ) {
        self = .parented(entry: entry, crop: entry.crop(at: time), unit: unit)
    }

    // MARK: - Public
    // A clip's area at the time, its keyframes carried by its track when it is tracked.
    func area(
        of keyframes: [Keyframe<Rectangle>],
        track: ResolvedTrack?,
        at time: Double
    ) -> Rectangle {
        switch self {
        case .output:
            return keyframes.value(at: time)

        case let .parented(entry, crop, unit):
            let area = track?.area(of: keyframes, on: entry, at: time) ?? keyframes.value(at: time)
            return CropConformer().output(of: area, crop: crop, content: unit)
        }
    }

    // The top left of a box clip's box at the time. A parented clip's anchor point, `position + anchor` in media
    // pixels and carried by its track when it is tracked, is mapped into the unit, and the box keeps its size in
    // output pixels around it.
    func position(
        of box: ResolvedBox,
        track: ResolvedTrack?,
        at time: Double
    ) -> Point {
        switch self {
        case .output:
            return box.position.value(at: time)

        case let .parented(entry, crop, unit):
            let anchors = box.position.map { keyframe in
                Keyframe(
                    at: keyframe.at,
                    value: Point(x: keyframe.value.x + box.anchor.x, y: keyframe.value.y + box.anchor.y),
                    ease: keyframe.ease
                )
            }
            let anchor = track?.point(of: anchors, on: entry, at: time) ?? anchors.value(at: time)
            let scale = unit.width / crop.width

            return Point(
                x: unit.x + (anchor.x - crop.x) * scale - box.anchor.x,
                y: unit.y + (anchor.y - crop.y) * scale - box.anchor.y
            )
        }
    }

    // MARK: - Private
}
