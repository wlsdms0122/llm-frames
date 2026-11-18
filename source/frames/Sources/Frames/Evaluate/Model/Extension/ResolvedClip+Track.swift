//
//  ResolvedClip+Track.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What a clips entry's track moves (FRAMES-12). A media clip of video or image sequence follows its own media on its
// own clock, which moves its crop and masks in its media pixels, as a storyline entry's are, while the clip stays
// where its own transform puts it. Any other clip follows its parent's media, and the motion is a moving parent of
// the clip.
extension ResolvedClip {
    // MARK: - Property
    // The track that moves the clip in its parent's space, nil when it has none or follows its own media.
    var parentTrack: ResolvedTrack? {
        ownTrackedMedia == nil ? track : nil
    }

    // The clip's own media when its track follows that media, nil when it has no track or follows its parent's.
    var ownTrackedMedia: PinnedMedia? {
        guard
            track != nil,
            case let .media(media) = content,
            case let .pinned(pinned) = media.media,
            !pinned.frameTimes.isEmpty
        else {
            return nil
        }

        return pinned
    }

    // The clock of the clip's own media when its track follows that media.
    private var ownMediaClock: MediaClock? {
        ownTrackedMedia == nil ? nil : clock
    }

    // MARK: - Initializer
    // MARK: - Public
    // A media clip's crop at the time in its media pixels, nil without one.
    func crop(at time: Double) -> Rectangle? {
        guard let crop else { return nil }
        guard let track, let clock = ownMediaClock else { return crop.value(at: time).rectangle }

        return track.crop(of: crop, on: clock, at: time)
    }

    // The clip's masks at the time in its own space, empty for none, each keyframe brought back to the instant when its
    // track follows its own media.
    func ownMasks(at time: Double) -> [ResolvedMask] {
        guard let mask else { return [] }
        guard let track, let clock = ownMediaClock else { return mask.value(at: time) }

        return track.masks(of: mask, on: clock, at: time)
    }

    // The motion that carries the clip's own masks in its own space at the time, the identity unless its track follows
    // its own media.
    func ownMotion(at time: Double) -> AffineTransform {
        guard let track, let clock = ownMediaClock else { return .identity }

        return track.transform(on: clock, at: time)
    }

    // MARK: - Private
}
