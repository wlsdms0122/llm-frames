//
//  DisplayList+Pixels.swift
//  FramesQuartz
//
//  Created by JSilver on 11/22/26.
//

import Frames

extension DisplayList {
    // MARK: - Property
    // Whether the list draws a picture of pixels, a frame of raster media, itself, in a nested list or in a track matte's
    // source, in any of its sample lists for a list with samples. A page of a PDF is none, since it is asked for at the
    // scale it is shown at.
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
                case let .media(frame):
                    if frame.picture != .page { return true }

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
