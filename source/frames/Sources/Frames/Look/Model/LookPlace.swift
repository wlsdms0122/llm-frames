//
//  LookPlace.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A place in a key of a clip's look, which the clip writes in two places: its static value under the key on the clip,
// and each keyframe's under the key in that keyframe. `path` is the same below the key in both.
struct LookPlace: Equatable, Sendable {
    // MARK: - Property
    let clip: Place
    let key: String
    let path: Place

    var written: Place {
        clip.appending(key: key).appending(path)
    }

    // MARK: - Initializer
    init(
        clip: Place,
        key: String,
        path: Place = .root
    ) {
        self.clip = clip
        self.key = key
        self.path = path
    }

    // MARK: - Public
    func keyframe(_ index: Int) -> Place {
        clip.appending(key: "keyframes").appending(index: index).appending(key: key).appending(path)
    }

    func appending(key: String) -> LookPlace {
        LookPlace(clip: clip, key: self.key, path: path.appending(key: key))
    }

    func appending(index: Int) -> LookPlace {
        LookPlace(clip: clip, key: key, path: path.appending(index: index))
    }

    // MARK: - Private
}
