//
//  ResolvedTransition+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A transition plan by its range, with its cover's colour as a value and its cover and matte files pinned.
extension ResolvedTransition {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: TransitionPlan,
        hashes: any FileHashProvider
    ) throws {
        let definition = plan.definition
        let cover = try definition.cover.map { cover in
            let source: ResolvedCoverSource = switch cover.source {
            case let .color(color):
                .color(Color(written: color))

            case let .media(media):
                .media(try PinnedMedia(path: media, hashes: hashes))
            }

            return ResolvedCover(source: source, span: cover.span)
        }
        let matte = try definition.matte.map { matte in
            ResolvedMatte(
                media: try PinnedMedia(path: matte.media, hashes: hashes),
                softness: matte.softness,
                isInverted: matte.isInverted,
                ease: matte.ease
            )
        }

        self.init(
            start: plan.range.start,
            end: plan.range.end,
            over: definition.over,
            incoming: definition.incoming,
            outgoing: definition.outgoing,
            cover: cover,
            matte: matte
        )
    }

    // MARK: - Public
    // MARK: - Private
}
