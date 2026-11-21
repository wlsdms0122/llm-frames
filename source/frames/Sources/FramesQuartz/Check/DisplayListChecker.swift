//
//  DisplayListChecker.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Walks a display list and the lists nested in it for what the quartz renderer cannot draw, naming each refusal with
// its place in the list. It draws every item kind and filter operation, so what it refuses is a blend mode it has no
// kernel for, a `lut` whose `.cube` does not read as a 3D LUT, and a corner pin on a picture other than a clip's group
// (FRAMES-20 Pictures): it warps a nested list's raster onto the corner pin, and a group has no filter, matte, radius,
// border, shadow or reveal. It reads each LUT through the renderer's cache, so drawing reads none again.
struct DisplayListChecker {
    // MARK: - Property
    private let tables: LookUpTableCache

    // MARK: - Initializer
    init(tables: LookUpTableCache) {
        self.tables = tables
    }

    // MARK: - Public
    // `place` is the path of the list in the outermost one, empty for the outermost.
    func check(
        _ list: DisplayList,
        place: String = ""
    ) throws {
        for (index, item) in list.items.enumerated() {
            let itemPlace = "\(place)items[\(index)]"
            guard BlendMode(rawValue: item.blend) != nil else {
                throw QuartzError.unsupportedBlend(name: item.blend, place: "\(itemPlace).blend")
            }
            if let trackMatte = item.trackMatte {
                try check(trackMatte.source, place: "\(itemPlace).trackMatte.source.")
            }

            switch item.content {
            case let .picture(picture):
                if picture.cornerPin != nil {
                    try checkCornerPin(of: picture, reveal: item.reveal, place: itemPlace)
                }
                try check(picture.filter, place: itemPlace)
                if case let .displayList(nested) = picture.source {
                    try check(nested, place: "\(itemPlace).source.")
                }

            case let .adjust(adjust):
                try check(adjust.filter, place: itemPlace)

            case .path, .glyphs:
                break
            }
        }
    }

    // MARK: - Private
    // `place` is the item's.
    private func checkCornerPin(
        of picture: PictureItem,
        reveal: Rectangle?,
        place: String
    ) throws {
        guard
            case .displayList = picture.source,
            picture.filter.isEmpty,
            picture.matte == nil,
            picture.radius == 0,
            picture.border == nil,
            picture.shadow == nil,
            reveal == nil
        else {
            throw QuartzError.unsupportedCornerPin(place: "\(place).cornerPin")
        }
    }

    // `place` is the item's.
    private func check(
        _ filter: [FilterEntry],
        place: String
    ) throws {
        for (index, entry) in filter.enumerated() {
            for (operationIndex, operation) in entry.operations.enumerated() {
                try check(operation, place: "\(place).filter[\(index)].ops[\(operationIndex)]")
            }
        }
    }

    // The switch names every operation and has no `default`, so an operation added to `ResolvedFilterOperation` stops
    // the build here until the renderer draws it or refuses it.
    private func check(
        _ operation: ResolvedFilterOperation,
        place: String
    ) throws {
        switch operation {
        case let .lut(file, _, _):
            do {
                _ = try tables.table(of: file)
            } catch let error as FilterError {
                throw QuartzError.unreadableTable(place: place, error: error)
            }

        case .exposure, .contrast, .saturation, .temperature, .hue, .sepia, .levels, .blur, .sharpen, .bloom, .vignette,
            .pixelate, .grain:
            break
        }
    }
}
