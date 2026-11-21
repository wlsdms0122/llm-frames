//
//  PageReadingRefusal+Resolved.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

extension PageReadingRefusal {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The stop of a resolved entry that reads a page as a page is not, naming the value refused: its `colorSpace`, read
    // from `colorSpace`, or its `toneMap`, read from `toneMap`. An entry that reads no `toneMap` gives nil for it, and
    // a page refuses a `toneMap` only where one is read.
    func error(
        colorSpace: PlacedJSONValue,
        toneMap: PlacedJSONValue?
    ) -> ModelError {
        switch self {
        case .toneMap:
            guard let toneMap else { preconditionFailure("a page refuses a toneMap only where one is read") }

            return ModelError.invalidValue(
                place: toneMap.place,
                kind: toneMap.kind,
                reason: "a page is not HDR and takes no toneMap, so it is null here, found \(toneMap.value.written)"
            )

        case let .colorSpace(refused):
            return ModelError.unknownValue(
                place: colorSpace.place,
                kind: colorSpace.kind,
                value: refused.rawValue,
                allowed: VocabularyTable.standardDynamicRangeColorSpaces
            )
        }
    }

    // MARK: - Private
}
