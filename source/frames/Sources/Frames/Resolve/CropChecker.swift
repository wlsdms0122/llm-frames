//
//  CropChecker.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Stops a clip whose crop, conformed to its box, shows none of its media, since it is never visible. Only a static
// crop of an untracked clip is checked: keyframes and a track move a crop, and it may reach the media between them.
struct CropChecker: Sendable {
    // MARK: - Property
    private let conformer = CropConformer()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func check(
        _ crop: PropertyValue<FoundArea>?,
        of picture: Picture,
        box: Size,
        conform: Conform,
        isTracked: Bool,
        place: Place,
        kind: PlaceKind
    ) throws {
        guard !isTracked, case let .value(area) = crop else { return }

        let bounds = Rectangle(x: 0, y: 0, width: box.width, height: box.height)
        let conformed = conformer.conformed(area.rectangle, to: bounds, by: conform)
        guard conformed.intersection(picture.bounds) == nil else { return }

        throw ResolveError.cropOutsideMedia(place: place, kind: kind, crop: conformed, size: picture.size)
    }

    // MARK: - Private
}
