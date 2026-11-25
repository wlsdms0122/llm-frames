//
//  ResolvedClip+Track.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A media clip of video or image sequence without a corner pin tracks its own media on its own clock, which moves its
// crop and masks in its media pixels while the clip stays where its own transform puts it. Any other clip, one with a
// corner pin included, tracks its parent's media, and the motion is a moving parent of the clip (FRAMES-12).
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
            case let .picture(.media(media), .transform, _) = content,
            case let .pinned(pinned) = media.media,
            pinned.frameTimes != nil
        else {
            return nil
        }

        return pinned
    }

    private var ownMediaClock: MediaClock? {
        ownTrackedMedia == nil ? nil : clock
    }

    // MARK: - Initializer
    // MARK: - Public
    // The crop in its media pixels of `media`, the clip's own picture, where its track moves it.
    func crop(
        of media: ResolvedMediaClip,
        at time: SampleTime
    ) -> Rectangle {
        guard let track, let clock = ownMediaClock else { return media.crop.value(at: time).rectangle }

        return track.crop(of: media.crop, on: clock, at: time)
    }

    // The clip's masks in its own space.
    func ownMasks(at time: SampleTime) -> [MaskSample] {
        guard let mask = composite?.mask else { return [] }
        guard let track, let clock = ownMediaClock else { return mask.map { $0.sampled(at: time) } }

        return track.masks(of: mask, on: clock, at: time)
    }

    // The motion that carries the clip's own masks in its own space at the time, the identity unless its track follows
    // its own media.
    func ownMotion(at time: SampleTime) -> AffineTransform {
        guard let track, let clock = ownMediaClock else { return .identity }

        return track.transform(on: clock, at: time)
    }

    // MARK: - Private
}
