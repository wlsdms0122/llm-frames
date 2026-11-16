//
//  PicturePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans an image or layout document: what it takes first, as the pictures they draw (an image document's source, a
// layout's items), then the document over them. A nested sequence is planned by the caller, which owns the recursion.
struct PicturePlanner: Sendable {
    // MARK: - Property
    private let image: ImagePlanner
    private let layout: LayoutPlanner

    // MARK: - Initializer
    init(
        ocr: any OCRProvider,
        presets: any PresetProvider,
        text: ThemeTypesetter,
        library: ReferenceLibrary
    ) {
        self.image = ImagePlanner(ocr: ocr, presets: presets, text: text, library: library)
        self.layout = LayoutPlanner(text: text)
    }

    // MARK: - Public
    func plan(
        _ picture: NestedPicture,
        sequences: (TimePlan) throws -> SequencePlan
    ) throws -> PicturePlan {
        switch picture.document {
        case let .image(document):
            let source = try drawn(
                picture.media[0],
                time: document.time,
                place: document.place.appending(key: "source"),
                kind: .image,
                sequences: sequences
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
                    kind: .layoutItem,
                    sequences: sequences
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
        kind: PlaceKind,
        sequences: (TimePlan) throws -> SequencePlan
    ) throws -> (drawn: DrawnPicture, picture: Picture) {
        switch media.source {
        case let .file(file):
            let name = media.reference ?? file.path
            guard let size = file.size else {
                throw ResolveError.soundAsPicture(place: place, kind: kind, reference: name)
            }

            let picture = Picture(name: name, source: .mediaFile(file), size: size)

            return (.media(file, name: name, time: media.clamped(time)), picture)

        case let .sequence(nested):
            let plan = try sequences(nested)
            let name = media.reference ?? place.description
            let picture = Picture(name: name, source: .document, size: plan.format.size)

            return (.sequence(plan, time: media.clamped(time)), picture)

        case let .picture(nested):
            let plan = try plan(nested, sequences: sequences)
            let picture = Picture(name: media.reference ?? place.description, source: .document, size: plan.size)

            return (.picture(plan), picture)
        }
    }
}
