//
//  ImagePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans an image document: runs its operations in order on its canvas and gives the final size and the drawing steps.
// Areas and points are written in the media pixels of the source and mapped through the canvas operations before
// them, so they reach into pads and banners only after those. Text areas are found by the OCR provider in the source
// picture at the document's `time`. A drawing is made with theme lengths scaled by the canvas width at its operation
// and clipped to that canvas, and one wholly outside it stops.
struct ImagePlanner: Sendable {
    // MARK: - Property
    private let finder: AreaFinder
    private let filters: FilterResolver
    private let text: ThemeTypesetter
    private let banners: BannerSetter
    private let sideFinder = LabelSideFinder()

    // MARK: - Initializer
    init(
        ocr: any OCRProvider,
        presets: any PresetProvider,
        text: ThemeTypesetter,
        library: ReferenceLibrary
    ) {
        self.finder = AreaFinder(ocr: ocr)
        self.filters = FilterResolver(presets: presets, library: library)
        self.text = text
        self.banners = BannerSetter(text: text)
    }

    // MARK: - Public
    // `source` is what the document's source draws, and `picture` what its text areas are found in at `time`, the
    // document's own clamped into the media.
    func plan(
        _ document: ImageDocument,
        theme: MergedTheme,
        source: DrawnPicture,
        picture: Picture,
        time: Double
    ) throws -> PicturePlan {
        var canvas = ImageCanvas(picture: source, size: picture.size)
        for operation in document.operations {
            try run(operation, on: &canvas, time: time, picture: picture, theme: theme)
        }

        return PicturePlan(kind: "image", size: canvas.size, steps: canvas.steps)
    }

    // MARK: - Private
    private func run(
        _ operation: ImageOperation,
        on canvas: inout ImageCanvas,
        time: Double,
        picture: Picture,
        theme: MergedTheme
    ) throws {
        let place = operation.place
        let scale = theme.lengthScale(at: canvas.size.width)
        func find(
            _ form: AreaForm,
            _ key: String,
            _ kind: PlaceKind,
            _ padding: Double
        ) throws -> Rectangle {
            try area(
                form,
                on: canvas,
                time: time,
                picture: picture,
                padding: padding,
                theme: theme,
                place: place.appending(key: key),
                kind: kind
            )
        }

        switch operation.content {
        case let .crop(form):
            let area = try find(form, "crop", .operation(.crop), theme.cropPadding)
            // A canvas is whole pixels, so a crop keeps every pixel its area touches.
            let left = area.x.rounded(.down)
            let top = area.y.rounded(.down)
            canvas.crop(to: Rectangle(
                x: left,
                y: top,
                width: area.maxX.rounded(.up) - left,
                height: area.maxY.rounded(.up) - top
            ))

        case let .resize(form):
            let size = canvas.size
            let target = switch form {
            case let .scale(scale):
                Size(width: size.width * scale, height: size.height * scale)

            case let .width(width):
                Size(width: width, height: size.height * width / size.width)

            case let .height(height):
                Size(width: size.width * height / size.height, height: height)
            }
            // A canvas is whole pixels, so the target size is found first and the canvas maps onto it.
            canvas.resize(to: Size(
                width: max(target.width.rounded(), 1),
                height: max(target.height.rounded(), 1)
            ))

        case let .pad(inset, color):
            canvas.extend(by: inset, color: theme.color(color ?? "background"))

        case let .shape(shape, form, label, color):
            let kind = PlaceKind.shape(shape.kind)
            let area = try find(form, "area", kind, theme.areaPadding)
            let box = draw(
                shape,
                area: area,
                color: color.map(theme.color) ?? theme.shapeColor(of: shape.kind),
                on: &canvas,
                scale: scale,
                theme: theme
            )
            if let label {
                try draw(label, beside: box, on: &canvas, scale: scale, theme: theme, place: place, kind: kind)
            }

        case let .adjust(choice, form):
            let kind = PlaceKind.operation(.adjust)
            let area = try form.map { try find($0, "area", kind, theme.areaPadding) } ?? canvas.bounds
            let operations = try filters.operations(of: choice, place: place.appending(key: "adjust"), kind: kind)
            canvas.draw(.adjustment(operations.map { $0.scaled(by: scale) }, area: area))

        case let .title(title, position, anchor, style, width):
            let kind = PlaceKind.operation(.title)
            let point = switch position {
            case let .point(point):
                canvas.transform.point(point)

            case let .area(form, name):
                try find(form, "position", kind, theme.areaPadding).point(named: name)
            }
            let layout = try text.layout(
                title,
                style: style,
                width: width.map(canvas.transform.length) ?? canvas.size.width - theme.placementPadding * scale * 2,
                theme: theme,
                scale: scale,
                place: place.appending(key: "title"),
                kind: kind.label
            )
            let box = Rectangle(x: 0, y: 0, width: layout.size.width, height: layout.size.height)
            let anchorPoint = box.point(named: anchor)
            let frame = Rectangle(
                x: point.x - anchorPoint.x,
                y: point.y - anchorPoint.y,
                width: box.width,
                height: box.height
            )
            guard frame.intersection(canvas.bounds) != nil else {
                throw ResolveError.outsideCanvas(place: place.appending(key: "position"), kind: kind, size: canvas.size)
            }
            canvas.draw(.text(layout, frame: frame))

        case let .banner(lines, edge):
            let banner = try banners.banner(
                lines,
                width: canvas.size.width,
                top: edge == .top ? 0 : canvas.size.height,
                theme: theme,
                scale: scale,
                place: place.appending(key: "banner"),
                kind: PlaceKind.operation(.banner).label
            )
            canvas.extend(
                by: Inset(
                    top: edge == .top ? banner.height : 0,
                    right: 0,
                    bottom: edge == .top ? 0 : banner.height,
                    left: 0
                ),
                color: theme.color("background")
            )
            for line in banner.text {
                canvas.draw(line)
            }

        case let .border(color):
            canvas.draw(.border(canvas.bounds, width: theme.borderWidth * scale, color: theme.color(color)))
        }
    }

    // An area in canvas pixels, cut to the canvas. Text is found in the source picture, grown by padding in that
    // picture's pixels, and a band spans the canvas.
    private func area(
        _ form: AreaForm,
        on canvas: ImageCanvas,
        time: Double,
        picture: Picture,
        padding: Double,
        theme: MergedTheme,
        place: Place,
        kind: PlaceKind
    ) throws -> Rectangle {
        let mapped: Rectangle
        switch form {
        case let .rectangle(rectangle):
            mapped = canvas.transform.rectangle(rectangle)

        case .text, .range:
            let found = try finder.area(
                form,
                in: picture,
                atMediaTime: time,
                padding: padding * theme.lengthScale(at: picture.size.width),
                place: place,
                kind: kind.label
            )
            mapped = canvas.transform.rectangle(found.rectangle)

        case let .band(inner):
            let area = try self.area(
                inner,
                on: canvas,
                time: time,
                picture: picture,
                padding: padding,
                theme: theme,
                place: place,
                kind: kind
            )
            mapped = Rectangle(x: 0, y: area.y, width: canvas.size.width, height: area.height)
        }
        guard let cut = mapped.intersection(canvas.bounds) else {
            throw ResolveError.outsideCanvas(place: place, kind: kind, size: canvas.size)
        }

        return cut
    }

    // Draws a shape on its area and gives the box its label is measured beside: the area, or the arrow's.
    private func draw(
        _ shape: ShapeForm,
        area: Rectangle,
        color: Color,
        on canvas: inout ImageCanvas,
        scale: Double,
        theme: MergedTheme
    ) -> Rectangle {
        switch shape {
        case .box:
            canvas.draw(.box(area, width: theme.boxWidth * scale, radius: theme.boxRadius * scale, color: color))
            return area

        case .fill:
            canvas.draw(.fill(area, color: color))
            return area

        case .dim:
            canvas.draw(.dim(area, color: color))
            return area

        case let .arrow(side):
            let arrow = Arrow(pointingAt: area, from: side, theme: theme, scale: scale)
            canvas.draw(.arrow(
                tail: arrow.tail,
                tip: arrow.tip,
                width: theme.arrowWidth * scale,
                head: theme.arrowHead * scale,
                color: color
            ))

            return arrow.box
        }
    }

    // A label is set on one line in the `label` style, and its room is the canvas at its shape's operation.
    private func draw(
        _ label: String,
        beside box: Rectangle,
        on canvas: inout ImageCanvas,
        scale: Double,
        theme: MergedTheme,
        place: Place,
        kind: PlaceKind
    ) throws {
        let place = place.appending(key: "label")
        let layout = try text.layout(
            label,
            style: "label",
            width: nil,
            theme: theme,
            scale: scale,
            place: place,
            kind: kind.label
        )
        let sides = theme.labelSides
        guard let side = sideFinder.side(of: layout.size, beside: box, in: canvas.bounds, sides: sides) else {
            throw ResolveError.labelWithoutRoom(place: place, kind: kind, label: label, sides: sides, room: "canvas")
        }

        canvas.draw(.text(layout, frame: sideFinder.rectangle(of: layout.size, beside: box, on: side)))
    }
}
