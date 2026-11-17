//
//  ResolvedClip+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A connected or sequence clip as resolve decided it, every static property one keyframe at the clip's instant. A title
// or media clip carries its box, a shape or adjustment its area. Scale and rotation belong to a title or media clip,
// and a blend mode to anything drawn but an adjustment.
extension ResolvedClip {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: ClipPlan,
        geometry: ClipGeometry,
        hashes: any FileHashProvider
    ) throws {
        let instant = plan.instant
        let appearance = geometry.appearance
        let content = try Self.content(of: plan, geometry: geometry, hashes: hashes)
        let isTransformed = switch content {
        case .title, .media:
            true

        case .shape, .adjustment:
            false
        }
        let isBlended = if case .adjustment = content { false } else { true }

        self.init(
            place: plan.place.description,
            id: plan.id,
            content: content,
            start: plan.visible.start,
            end: plan.visible.end,
            lane: plan.lane,
            storyline: plan.storyline,
            parent: plan.parent?.id,
            area: geometry.area?.keyframes(at: instant) { $0.rectangle },
            box: geometry.box.map { box in
                ResolvedBox(size: box.size, position: box.position.keyframes(at: instant) { $0 }, anchor: box.anchor)
            },
            crop: appearance.media?.crop.keyframes(at: instant) { Crop($0) },
            track: geometry.track.map { ResolvedTrack(track: $0) },
            opacity: appearance.opacity.keyframes(at: instant) { $0 },
            scale: isTransformed ? appearance.scale.keyframes(at: instant) { $0 } : nil,
            rotation: isTransformed ? appearance.rotation.keyframes(at: instant) { $0 } : nil,
            blend: isBlended ? appearance.blend : nil,
            animation: ResolvedAnimation(plan: plan.animation)
        )
    }

    // MARK: - Public
    // MARK: - Private
    // A title is the one clip set as text, a shape the one drawn on its area, and a media clip the one with a picture that
    // fills its box, so what is left is an adjustment.
    private static func content(
        of plan: ClipPlan,
        geometry: ClipGeometry,
        hashes: any FileHashProvider
    ) throws -> ResolvedClipContent {
        let appearance = geometry.appearance
        let filter = try appearance.filter.map { try ResolvedFilterOperation(operation: $0, hashes: hashes) }

        if let title = geometry.title {
            return .title(try ResolvedText(layout: title, hashes: hashes))
        }
        if let drawing = appearance.shape {
            return .shape(drawing)
        }
        if
            let media = try ResolvedMediaContent(media: plan.media, nested: geometry.nested, hashes: hashes),
            let fill = appearance.media
        {
            return .media(ResolvedMediaClip(
                media: media,
                timing: plan.timing.map { timing in
                    ResolvedMediaTiming(
                        in: timing.map.in,
                        origin: timing.map.origin,
                        out: timing.out,
                        speed: timing.map.speed,
                        loop: timing.loop
                    )
                },
                filter: filter,
                appearance: ResolvedMediaAppearance(
                    conform: fill.conform,
                    radius: fill.radius,
                    border: fill.border,
                    shadow: fill.shadow
                )
            ))
        }

        return .adjustment(filter)
    }
}
