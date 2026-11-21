//
//  ItemOrigin.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The clip that drew a display item: its place in the document, continued into a nested sequence from the clip that
// holds it, its `id`, and its kind as `timeline` names it. `unit` is the index among its title's units of the unit
// that drew an item of a title animated by unit, and nil for any other item.
package struct ItemOrigin: Equatable, Sendable {
    // MARK: - Property
    package let place: String
    package let id: String?
    package let kind: String
    package let unit: Int?

    // MARK: - Initializer
    package init(
        place: String,
        id: String?,
        kind: String,
        unit: Int? = nil
    ) {
        self.place = place
        self.id = id
        self.kind = kind
        self.unit = unit
    }

    init(clip: ResolvedClip) {
        let kind: ClipKind = switch clip.content {
        case .title:
            .title

        case let .shape(shape):
            .shape(shape.kind.rawValue)

        case .adjustment:
            .adjust

        case let .media(media):
            .media(Self.kind(of: media.media))
        }

        self.init(place: clip.place, id: clip.id, kind: kind.label)
    }

    init(entry: ResolvedStorylineClip) {
        let kind: ClipKind = entry.media.map { .media(Self.kind(of: $0)) } ?? .solid

        self.init(place: entry.place, id: entry.id, kind: kind.label)
    }

    // MARK: - Public
    // The same clip, drawing the unit at `index` of its title.
    func drawing(unit index: Int) -> ItemOrigin {
        ItemOrigin(place: place, id: id, kind: kind, unit: index)
    }

    // MARK: - Private
    // Pinned media with frame times is a video or image sequence, and without them a still. A nested sequence is a
    // compound clip or a template instance.
    private static func kind(of media: ResolvedMediaContent) -> MediaKind {
        switch media {
        case let .pinned(media):
            media.frameTimes.isEmpty ? .image : .video

        case .nested:
            .sequence
        }
    }
}
