//
//  PictureReader.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads an image or layout document that passed the key tables into model types, once, with the place of every
// operation and item. The media it takes is read as a sequence reads media, so a template's arguments keep their
// themes.
struct PictureReader: Sendable {
    // MARK: - Property
    private let argumentThemes: ArgumentThemeTable

    // MARK: - Initializer
    init(argumentThemes: ArgumentThemeTable = .empty) {
        self.argumentThemes = argumentThemes
    }

    // MARK: - Public
    func picture(
        from document: JSONValue,
        place: Place = .root
    ) -> PictureDocument {
        let object = document.objectValue ?? JSONObject()
        let theme = object["theme"].map(ThemeReference.init(value:))
        // A sequence reader holds a picture reader, so the one for media is made when it is needed.
        let media = SequenceReader(argumentThemes: argumentThemes)
        guard object["kind"]?.stringValue == "layout" else {
            let operationsPlace = place.appending(key: "ops")
            let operations = (object["ops"]?.arrayValue ?? []).enumerated().map { index, element in
                let operation = element.objectValue ?? JSONObject()

                return ImageOperation(
                    place: operationsPlace.appending(index: index, id: operation["id"]?.stringValue),
                    content: content(of: operation)
                )
            }

            return .image(ImageDocument(
                place: place,
                source: media.source(object["source"] ?? .null, place: place.appending(key: "source")),
                time: object["time"]?.numberValue ?? 0,
                theme: theme,
                operations: operations
            ))
        }

        let itemsPlace = place.appending(key: "items")
        let items = (object["items"]?.arrayValue ?? []).enumerated().map { index, element in
            let item = element.objectValue ?? JSONObject()
            let itemPlace = itemsPlace.appending(index: index)

            return LayoutItem(
                place: itemPlace,
                heading: item["heading"]?.stringValue,
                source: media.source(item["image"] ?? .null, place: itemPlace.appending(key: "image"))
            )
        }

        return .layout(LayoutDocument(
            place: place,
            theme: theme,
            banner: lines(of: object["banner"]),
            columns: object["columns"]?.numberValue.map { Int($0) },
            border: border(of: object["border"] ?? .bool(true)),
            items: items
        ))
    }

    // MARK: - Private
    // The key tables let exactly one operation key through, so the first that is there names the operation.
    private func content(of operation: JSONObject) -> ImageOperationContent {
        let color = operation["color"]?.stringValue
        if let crop = operation["crop"] {
            return .crop(area(of: crop))
        }
        if let resize = operation["resize"]?.objectValue {
            return resizeForm(of: resize)
        }
        if let pad = operation["pad"] {
            return .pad(inset(of: pad), color: color)
        }
        if let shape = operation["shape"]?.stringValue {
            return .shape(
                shape,
                area: area(of: operation["area"] ?? .null),
                label: operation["label"]?.stringValue,
                side: operation["side"]?.stringValue.flatMap(Side.init),
                color: color
            )
        }
        if let adjust = operation["adjust"] {
            return .adjust(adjust, area: operation["area"].flatMap(AreaForm.init(value:)))
        }
        if let title = operation["title"]?.stringValue {
            return .title(
                title,
                position: operation["position"].flatMap(PositionForm.init(value:)) ?? .point(Point(x: 0, y: 0)),
                anchor: operation["anchor"]?.stringValue ?? "center",
                style: operation["style"]?.stringValue ?? "",
                width: operation["width"]?.numberValue
            )
        }
        if let banner = operation["banner"] {
            return .banner(lines(of: banner), edge: operation["edge"]?.stringValue.flatMap(Side.init) ?? .top)
        }

        return .border(color: border(of: operation["border"] ?? .bool(true)) ?? "border")
    }

    private func resizeForm(of resize: JSONObject) -> ImageOperationContent {
        if let width = resize["width"]?.numberValue {
            return .resize(.width(width))
        }
        if let height = resize["height"]?.numberValue {
            return .resize(.height(height))
        }

        return .resize(.scale(resize["scale"]?.numberValue ?? 1))
    }

    private func area(of value: JSONValue) -> AreaForm {
        AreaForm(value: value) ?? .rectangle(Rectangle(x: 0, y: 0, width: 0, height: 0))
    }

    // `n` is every side, `[vertical, horizontal]` as CSS writes two values, and four values go clockwise from the top.
    private func inset(of value: JSONValue) -> Inset {
        let numbers = value.arrayValue?.compactMap(\.numberValue) ?? [value.numberValue ?? 0]

        return switch numbers.count {
        case 2:
            Inset(top: numbers[0], right: numbers[1], bottom: numbers[0], left: numbers[1])

        case 4:
            Inset(top: numbers[0], right: numbers[1], bottom: numbers[2], left: numbers[3])

        default:
            Inset(top: numbers[0], right: numbers[0], bottom: numbers[0], left: numbers[0])
        }
    }

    private func lines(of value: JSONValue?) -> [BannerLine] {
        (value?.arrayValue ?? []).map { line in
            guard let object = line.objectValue else { return BannerLine(text: line.stringValue ?? "", style: "banner") }

            return BannerLine(text: object["text"]?.stringValue ?? "", style: object["style"]?.stringValue ?? "banner")
        }
    }

    // `true` is the theme `border` colour and `false` no border.
    private func border(of value: JSONValue) -> String? {
        switch value {
        case .bool(true):
            "border"

        case let .string(color):
            color

        default:
            nil
        }
    }
}
