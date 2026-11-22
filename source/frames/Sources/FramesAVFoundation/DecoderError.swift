//
//  DecoderError.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import Frames

package enum DecoderError: Error, Equatable, CustomStringConvertible, Sendable {
    case unreadable(file: String)
    case unloadable(file: String, reason: String)
    case emptySequence(directory: String)
    case unequalFrame(file: String, size: Size, first: Size)
    case noFrame(file: String, index: Int, count: Int)
    case frameCount(file: String, pinned: Int, counted: Int)
    case noSound(file: String)
    case unconvertibleColor(file: String, reason: String)
    case pictureSize(file: String, width: Int, height: Int, largest: Int)
    case lockedDocument(file: String)
    case noPage(file: String, page: Int, count: Int)
    case noDocument(file: String)
    case unreadablePage(file: String, page: Int, fault: PageFault)
    case pageFrame(file: String, page: Int)
    case pageRegion(file: String, region: PageRegion, scale: Double)
    case pageBitmap(width: Int, height: Int)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .unreadable(file):
            "media \(file) cannot be read"

        case let .unloadable(file, reason):
            "media \(file) cannot be read: \(reason)"

        case let .emptySequence(directory):
            "image sequence \(directory) holds no PNG frames"

        case let .unequalFrame(file, size, first):
            "image sequence frame \(file) is \(written(size)), where the first frame is \(written(first))"

        case let .noFrame(file, index, count):
            "media \(file) has no frame \(index): it has \(count)"

        case let .frameCount(file, pinned, counted):
            "media \(file) has \(counted) frames where the resolved document pins \(pinned). Resolve it again"

        case let .noSound(file):
            "media \(file) has no sound track"

        case let .unconvertibleColor(file, reason):
            "media \(file) cannot be read: \(reason), which no fixed formula converts. Write the colorSpace it is in "
                + "where it is named, or convert it with transcode"

        case let .pictureSize(file, width, height, largest):
            "media \(file) gives a picture of \(width)x\(height), larger than the \(largest) pixels on a side this "
                + "decoder holds"

        case let .lockedDocument(file):
            "media \(file) cannot be read: the PDF opens only with a password"

        case let .noPage(file, page, count):
            "media \(file) has no page \(page): it has \(count)"

        case let .noDocument(file):
            "media \(file) is not a PDF, so it has no page"

        case let .unreadablePage(file, page, fault):
            fault.suggestsConversion
                ? "media \(file) page \(page) cannot be read: \(fault.reason). Convert it with transcode, or with a "
                    + "program that embeds its fonts"
                : "media \(file) page \(page) cannot be read: \(fault.reason)"

        case let .pageFrame(file, page):
            "media \(file) page \(page) is read by a region and a scale, not by a frame"

        case let .pageRegion(file, region, scale):
            "media \(file) cannot give the region \(region.width)x\(region.height) at scale \(scale): a region is at "
                + "least 1 pixel on a side, at a scale above 0"

        case let .pageBitmap(width, height):
            "a bitmap of \(width)x\(height) pixels to draw a page in cannot be made"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func written(_ size: Size) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }
}
