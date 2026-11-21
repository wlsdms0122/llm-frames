//
//  DisplayList+Pixels.swift
//  FramesQuartz
//
//  Created by JSilver on 11/22/26.
//

import Frames

extension DisplayList {
    // MARK: - Property
    // Whether the list draws a picture of pixels, a media frame, itself, in a nested list or in a track matte's source,
    // in any of its sample lists for a list with samples.
    var holdsPixels: Bool {
        let items = switch content {
        case let .items(items):
            items

        case let .samples(samples):
            samples.flatMap { $0 }
        }

        return items.contains { item in
            if case let .picture(picture) = item.content {
                switch picture.source {
                case .media:
                    return true

                case let .displayList(list):
                    if list.holdsPixels { return true }
                }
            }

            return item.trackMatte?.source.holdsPixels ?? false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
