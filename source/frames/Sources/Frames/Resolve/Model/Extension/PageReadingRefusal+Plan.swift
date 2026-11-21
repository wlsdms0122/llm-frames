//
//  PageReadingRefusal+Plan.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

extension PageReadingRefusal {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The stop of a transition's cover or matte that reads `page` of the PDF `reference` names as a page is not, at
    // `place`. A preset's media reads no `toneMap`, so a page refuses only its `colorSpace` here.
    func error(
        place: Place,
        kind: PlaceKind,
        reference: String,
        page: Int
    ) -> ModelError {
        switch self {
        case .toneMap:
            preconditionFailure("a page refuses a toneMap only where one is read")

        case let .colorSpace(refused):
            return ModelError.highDynamicRangePage(
                place: place,
                kind: kind.label,
                reference: reference,
                page: page,
                colorSpace: refused
            )
        }
    }

    // MARK: - Private
}
