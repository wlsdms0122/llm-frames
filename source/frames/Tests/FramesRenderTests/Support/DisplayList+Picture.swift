//
//  DisplayList+Picture.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation

@testable import Frames

extension DisplayList {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The picture items of media frames from the file named `name`, in this list and the lists nested in it, bottom
    // first.
    func mediaPictures(named name: String) -> [PictureItem] {
        drawnItems.flatMap { item -> [PictureItem] in
            guard case let .picture(picture) = item.content else { return [] }

            switch picture.source {
            case let .media(frame):
                let path = MediaFile(media: frame.media).path

                return (path as NSString).lastPathComponent == name ? [picture] : []

            case let .displayList(nested):
                return nested.mediaPictures(named: name)
            }
        }
    }

    // The boxes, in this list's pixels, of the media pictures from the file named `name` drawn in this list itself.
    func placedPictures(named name: String) -> [Rectangle] {
        drawnItems.compactMap { item -> Rectangle? in
            guard
                case let .picture(picture) = item.content,
                case let .media(frame) = picture.source,
                (MediaFile(media: frame.media).path as NSString).lastPathComponent == name
            else {
                return nil
            }

            let corners = item.transform.apply(toCornersOf: picture.destination)
            let left = corners.map(\.x).min() ?? 0
            let top = corners.map(\.y).min() ?? 0

            return Rectangle(
                x: left,
                y: top,
                width: (corners.map(\.x).max() ?? 0) - left,
                height: (corners.map(\.y).max() ?? 0) - top
            )
        }
    }

    // MARK: - Private
    // The list's items, or the items of all its sample lists in order.
    private var drawnItems: [DisplayItem] {
        switch content {
        case let .items(items):
            items

        case let .samples(samples):
            samples.flatMap { $0 }
        }
    }
}
