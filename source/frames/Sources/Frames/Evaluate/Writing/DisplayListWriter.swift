//
//  DisplayListWriter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Writes a display list in the layout and number form of a resolved document, so the same list gives the same bytes.
// A nested list has the same shape without the version, the colour space and the peak, which only the outermost
// carries.
package struct DisplayListWriter: Sendable {
    // MARK: - Property
    private let values = ResolvedValueWriter()
    private let writer = JSONWriter()

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func write(_ list: DisplayList) -> String {
        writer.write(document(list))
    }

    func document(_ list: DisplayList) -> JSONValue {
        .object(JSONObject(
            members: [JSONMember(key: "displayList", value: .string(FramesVersion.current))] + members(of: list)
        ))
    }

    // MARK: - Private
    private func members(of list: DisplayList) -> [JSONMember] {
        [
            JSONMember(key: "size", value: values.size(list.size)),
            JSONMember(key: "background", value: values.color(list.background)),
            list.colorSpace.map { JSONMember(key: "colorSpace", value: .string($0.rawValue)) },
            list.colorSpace.map { _ in JSONMember(key: "peak", value: list.peak.map { .number($0) } ?? .null) },
            JSONMember(key: "compositing", value: .string(list.compositing.rawValue)),
            items(of: list)
        ].compactMap { $0 }
    }

    // A list with samples writes them in place of its items, each sample a list of items.
    private func items(of list: DisplayList) -> JSONMember {
        let items = { (items: [DisplayItem]) in JSONValue.array(items.map { self.item(of: $0, seed: list.seed) }) }
        guard let samples = list.samples else { return JSONMember(key: "items", value: items(list.items)) }

        return JSONMember(key: "samples", value: .array(samples.map(items)))
    }

    private func item(
        of item: DisplayItem,
        seed: Int
    ) -> JSONValue {
        let origin = item.origin.map { origin in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "place", value: .string(origin.place)),
                JSONMember(key: "id", value: origin.id.map(JSONValue.string) ?? .null),
                JSONMember(key: "kind", value: .string(origin.kind))
            ]))
        }
        let members = [
            JSONMember(key: "item", value: .string(name(of: item.content))),
            JSONMember(key: "origin", value: origin ?? .null),
            JSONMember(key: "transform", value: values.numbers(item.transform.matrix)),
            JSONMember(key: "opacity", value: .number(item.opacity)),
            JSONMember(key: "blend", value: .string(item.blend)),
            JSONMember(key: "mask", value: item.mask.isEmpty ? .null : .array(item.mask.map(mask))),
            JSONMember(key: "trackMatte", value: item.trackMatte.map(trackMatte) ?? .null),
            JSONMember(key: "reveal", value: rectangle(item.reveal))
        ]

        return .object(JSONObject(members: members + self.members(of: item.content, seed: seed)))
    }

    private func name(of content: DisplayContent) -> String {
        switch content {
        case .picture:
            "picture"

        case .path:
            "path"

        case .glyphs:
            "glyphs"

        case .adjust:
            "adjust"
        }
    }

    private func members(
        of content: DisplayContent,
        seed: Int
    ) -> [JSONMember] {
        let number = { (key: String, number: Double) in JSONMember(key: key, value: .number(number)) }
        let color = { (color: Color) in JSONMember(key: "color", value: self.values.color(color)) }

        switch content {
        case let .picture(picture):
            return members(of: picture, seed: seed)

        case let .path(path):
            return members(of: path)

        case let .glyphs(glyphs):
            let background = glyphs.background.map { background in
                JSONValue.object(JSONObject(members: [
                    JSONMember(key: "rect", value: values.rectangle(background.rectangle)),
                    number("radius", background.radius),
                    color(background.color)
                ]))
            }
            return [
                JSONMember(key: "size", value: values.size(glyphs.size)),
                JSONMember(key: "runs", value: values.drawnRuns(glyphs.runs)),
                JSONMember(key: "layer", value: glyphs.layer.map { .string($0.rawValue) } ?? .null),
                JSONMember(key: "unitBox", value: glyphs.unitBox.map(values.rectangle) ?? .null),
                JSONMember(key: "unitGlyphBox", value: glyphs.unitGlyphBox.map(values.rectangle) ?? .null),
                JSONMember(key: "background", value: background ?? .null)
            ]

        case let .adjust(adjust):
            return [JSONMember(key: "filter", value: values.filter(adjust.filter, seed: seed))]
        }
    }

    // `rect` is `null` where the picture shows its whole source.
    private func members(
        of picture: PictureItem,
        seed: Int
    ) -> [JSONMember] {
        let border = picture.border.map { border in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "width", value: .number(border.width)),
                JSONMember(key: "color", value: values.color(border.color))
            ]))
        }
        let matte = picture.matte.map { matte in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "source", value: .object(JSONObject(members: values.media(matte.frame.media)))),
                JSONMember(key: "frame", value: .number(Double(matte.frame.index))),
                JSONMember(key: "colorSpace", value: colorSpace(of: matte.frame.reading)),
                JSONMember(key: "progress", value: .number(matte.progress)),
                JSONMember(key: "softness", value: .number(matte.softness)),
                JSONMember(key: "invert", value: .bool(matte.isInverted))
            ]))
        }

        return [
            JSONMember(key: "source", value: source(of: picture.source)),
            JSONMember(key: "rect", value: rectangle(picture.rectangle)),
            JSONMember(key: "dest", value: values.rectangle(picture.destination)),
            JSONMember(key: "filter", value: values.filter(picture.filter, seed: seed)),
            JSONMember(key: "matte", value: matte ?? .null),
            JSONMember(key: "radius", value: .number(picture.radius)),
            JSONMember(key: "border", value: border ?? .null),
            JSONMember(key: "shadow", value: shadow(picture.shadow))
        ]
    }

    private func members(of path: PathItem) -> [JSONMember] {
        let stroke = path.stroke.map { stroke in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "width", value: .number(stroke.width)),
                JSONMember(key: "paint", value: values.paint(stroke.paint)),
                JSONMember(key: "join", value: .string(stroke.join.rawValue)),
                JSONMember(key: "cap", value: .string(stroke.cap.rawValue)),
                JSONMember(key: "start", value: .string(stroke.start.rawValue)),
                JSONMember(key: "end", value: .string(stroke.end.rawValue)),
                JSONMember(key: "dash", value: stroke.dash.map { .array($0.map(JSONValue.number)) } ?? .null),
                JSONMember(key: "dashOffset", value: .number(stroke.dashOffset))
            ]))
        }

        return [
            JSONMember(key: "geometry", value: values.geometry(path.geometry)),
            JSONMember(key: "fill", value: path.fill.map(values.paint) ?? .null),
            JSONMember(key: "stroke", value: stroke ?? .null),
            JSONMember(key: "trim", value: values.numbers([path.trim.start, path.trim.end])),
            JSONMember(key: "shadow", value: shadow(path.shadow))
        ]
    }

    private func mask(_ mask: ItemMask) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "geometry", value: values.geometry(mask.geometry)),
            JSONMember(key: "transform", value: values.numbers(mask.transform.matrix)),
            JSONMember(key: "feather", value: .number(mask.feather)),
            JSONMember(key: "invert", value: .bool(mask.isInverted)),
            JSONMember(key: "mode", value: .string(mask.mode.rawValue))
        ]))
    }

    private func trackMatte(_ trackMatte: ItemTrackMatte) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "source", value: source(of: .displayList(trackMatte.source))),
            JSONMember(key: "mode", value: .string(trackMatte.mode.rawValue)),
            JSONMember(key: "invert", value: .bool(trackMatte.isInverted))
        ]))
    }

    private func shadow(_ shadow: DropShadow?) -> JSONValue {
        guard let shadow else { return .null }

        return .object(JSONObject(members: [
            JSONMember(key: "radius", value: .number(shadow.radius)),
            JSONMember(key: "offset", value: values.point(shadow.offset)),
            JSONMember(key: "color", value: values.color(shadow.color))
        ]))
    }

    private func source(of source: PictureItemSource) -> JSONValue {
        switch source {
        case let .media(frame):
            .object(JSONObject(members: [
                JSONMember(key: "media", value: .object(JSONObject(members: values.media(frame.media)))),
                JSONMember(key: "frame", value: .number(Double(frame.index))),
                JSONMember(key: "colorSpace", value: colorSpace(of: frame.reading)),
                JSONMember(key: "targetPeak", value: targetPeak(of: frame.reading))
            ]))

        case let .displayList(list):
            .object(JSONObject(members: [
                JSONMember(key: "list", value: .object(JSONObject(members: members(of: list))))
            ]))
        }
    }

    private func rectangle(_ rectangle: Rectangle?) -> JSONValue {
        rectangle.map(values.rectangle) ?? .null
    }

    // The space a picture is read in, null where its file's tags apply.
    private func colorSpace(of reading: PictureReading) -> JSONValue {
        reading.colorSpace.map { .string($0.rawValue) } ?? .null
    }

    // The peak a working read tone maps an HDR picture to, null where it takes it as display light. A matte, read as
    // an analysis picture, writes none.
    private func targetPeak(of reading: PictureReading) -> JSONValue {
        guard case let .working(_, targetPeak?) = reading else { return .null }

        return .number(targetPeak)
    }
}
