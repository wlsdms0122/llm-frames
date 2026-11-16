//
//  DisplayListChecker.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Walks a display list and the lists nested in it for what the quartz renderer cannot draw. It draws every item kind
// and filter operation, so what it refuses is a blend mode it has no kernel for, named with its place in the list.
struct DisplayListChecker {
    // MARK: - Property
    // MARK: - Initializer
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

            switch item.content {
            case let .picture(picture):
                picture.filter.forEach(check)
                if case let .displayList(nested) = picture.source {
                    try check(nested, place: "\(itemPlace).source.")
                }

            case let .adjust(adjust):
                adjust.filter.forEach(check)

            case .fill, .stroke, .arrow, .glyphs:
                break
            }
        }
    }

    // MARK: - Private
    // Every operation of FRAMES-15 has a Core Image form, so an operation added to the list stops the build here until
    // the renderer draws it or refuses it.
    private func check(_ operation: ResolvedFilterOperation) {
        switch operation {
        case .exposure, .contrast, .saturation, .temperature, .hue, .sepia, .levels, .lut, .blur, .sharpen, .bloom,
            .vignette, .pixelate, .grain:
            break
        }
    }
}
