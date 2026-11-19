//
//  TimePlan+TaggedColorSpaces.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

extension TimePlan {
    // MARK: - Property
    // The space of the table the tags of each media file name, for the files this plan and its nested plans name, by
    // the path of the file pinned first for it: the file, or an image sequence's first frame. A file whose tags name
    // no space of the table is left out.
    var taggedColorSpaces: [String: ColorSpace] {
        var spaces: [String: ColorSpace] = [:]
        for file in mediaFiles {
            guard let space = file.taggedColorSpace else { continue }

            spaces[file.frameFiles.first ?? file.path] = space
        }

        return spaces
    }

    // The media files of every storyline clip, its transition's cover and matte, and every other clip.
    private var mediaFiles: [MediaFile] {
        let storyline = storyline.flatMap { entry in
            Self.mediaFiles(of: entry.source.media)
                + [entry.transition?.coverMedia?.file, entry.transition?.matteMedia?.file].compactMap(\.self)
        }
        let clips = clips.flatMap { Self.mediaFiles(of: $0.media) }

        return storyline + clips
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private static func mediaFiles(of media: MediaPlan?) -> [MediaFile] {
        switch media?.source {
        case let .file(file):
            [file]

        case let .sequence(plan):
            plan.mediaFiles

        case nil:
            []
        }
    }
}
