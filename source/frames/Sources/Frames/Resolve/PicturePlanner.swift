//
//  PicturePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans an image or layout document: what it takes first, as the pictures they draw (an image document's source, a
// layout's items), then the document over them.
struct PicturePlanner: Sendable {
    // MARK: - Property
    private let image: ImagePlanner
    private let layout: LayoutPlanner
    private let ocr: any OCRProvider
    private let tracker: any TrackerProvider
    private let shaper: any ShapingProvider
    private let presets: any PresetProvider
    private let library: ReferenceLibrary

    // MARK: - Initializer
    init(
        ocr: any OCRProvider,
        tracker: any TrackerProvider,
        shaper: any ShapingProvider,
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        let text = ThemeTypesetter(shaper: shaper, library: library)
        self.image = ImagePlanner(ocr: ocr, presets: presets, text: text)
        self.layout = LayoutPlanner(text: text)
        self.ocr = ocr
        self.tracker = tracker
        self.shaper = shaper
        self.presets = presets
        self.library = library
    }

    // MARK: - Public
    func plan(_ picture: NestedPicture) throws -> PicturePlan {
        switch picture.document {
        case let .image(document):
            let source = try drawn(
                picture.media[0],
                time: document.time,
                place: document.place.appending(key: "source"),
                kind: .image
            )

            return try image.plan(
                document,
                theme: picture.theme,
                source: source.drawn,
                picture: source.picture,
                time: picture.media[0].clamped(document.time)
            )

        case let .layout(document):
            let items = try document.items.indices.map { index in
                let item = try drawn(
                    picture.media[index],
                    time: 0,
                    place: document.items[index].place.appending(key: "image"),
                    kind: .layoutItem
                )

                return (picture: item.drawn, size: item.picture.size)
            }

            return try layout.plan(document, theme: picture.theme, items: items)
        }
    }

    // MARK: - Private
    // What media draws at the media second, clamped into the media, and the picture its text is found in. A document
    // is drawn, not read, so no text is found in it.
    private func drawn(
        _ media: ResolvedMedia,
        time: Double,
        place: Place,
        kind: PlaceKind
    ) throws -> (drawn: DrawnPicture, picture: Picture) {
        let name = media.reference ?? media.file ?? place.description
        if let nested = media.picture {
            let plan = try plan(nested)

            return (.picture(plan), Picture(name: name, source: .document, size: plan.size))
        }
        if let nested = media.nested {
            // A sequence planner holds a picture planner, so the one for a compound clip is made when it is needed.
            let plan = try SequencePlanner(
                ocr: ocr,
                tracker: tracker,
                shaper: shaper,
                presets: presets,
                library: library
            ).plan(nested)
            let picture = Picture(name: name, source: .document, size: plan.format.size)

            return (.sequence(plan, time: media.clamped(time)), picture)
        }
        guard let file = media.file, let size = media.size else {
            throw ResolveError.soundAsPicture(place: place, kind: kind, reference: name)
        }

        return (.media(media, time: media.clamped(time)), Picture(name: name, source: .mediaFile(file), size: size))
    }
}
