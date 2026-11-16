//
//  ResolvedTransition+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A transition plan by its range, with its cover's colour as a value and its cover and matte media pinned with their
// frame times and length.
extension ResolvedTransition {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: TransitionPlan,
        hashes: any FileHashProvider
    ) throws {
        let definition = plan.definition
        // A cover or matte that shows media has it probed in the plan.
        let cover = try definition.cover.flatMap { cover -> ResolvedCover? in
            switch (cover.source, plan.coverMedia) {
            case let (.color(color), _):
                return ResolvedCover(source: .color(Color(written: color)), span: cover.span)

            case let (.media, .some(media)):
                return ResolvedCover(
                    source: .media(try ResolvedTransitionMedia(plan: media, hashes: hashes)),
                    span: cover.span
                )

            case (.media, .none):
                return nil
            }
        }
        let matte = try definition.matte.flatMap { matte in
            try plan.matteMedia.map { media in
                ResolvedMatte(
                    media: try ResolvedTransitionMedia(plan: media, hashes: hashes),
                    softness: matte.softness,
                    isInverted: matte.isInverted,
                    ease: matte.ease
                )
            }
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
