//
//  PageContentWalker.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation

// Reads what a page of a PDF draws with Core Graphics' own parser, the one the page is drawn with (FRAMES-3 PDF pages):
// its content streams and those of every form XObject, tiling pattern, soft mask group and Type 3 glyph they draw,
// inline images included, against the resources each is drawn with, the page's own or those it inherits. What is drawn
// is decided by operators and their state, not by what is shown: text in rendering mode 3 sets no glyph, content
// optional content hides is read, and annotations are not read. A colour space counts where
// drawn content paints in it, or blends in it as a transparency group's or a soft mask group's `/CS`. A Core Graphics
// operator callback is a C function, told nothing of its operator, so each operator has its own.
final class PageContentWalker {
    // MARK: - Property
    private static let deviceSpaces = ["DeviceGray": "DefaultGray", "DeviceRGB": "DefaultRGB", "DeviceCMYK": "DefaultCMYK"]
    private static let abbreviatedSpaces = ["G": "DeviceGray", "RGB": "DeviceRGB", "CMYK": "DeviceCMYK", "I": "Indexed"]

    private var states = [PageGraphicsState()]
    private var resources: [CGPDFDictionaryRef] = []
    private var faults: [PageFault] = []
    private var colorSpaces: [PDFValue] = []
    private var seenColorSpaces: Set<PDFValue> = []
    private var checkedFonts: Set<CGPDFDictionaryRef> = []
    private var scannedStreams: Set<ContentStreamScan> = []
    private var operators: CGPDFOperatorTableRef?
    private var contentStreams: [CGPDFContentStreamRef] = []
    private var uncoloredPatternDepth = 0
    // The fewest states the stream read now holds: its own first state is the last a `Q` in it restores to.
    private var stateBase = 1

    private var state: PageGraphicsState {
        get { states[states.count - 1] }
        set { states[states.count - 1] = newValue }
    }

    // MARK: - Initializer
    // MARK: - Public
    func content(of page: CGPDFPage) -> PageContent {
        guard let dictionary = page.dictionary else { return PageContent(faults: [], colorSpaces: []) }
        operators = Self.operatorTable()
        defer { operators.map(CGPDFOperatorTableRelease) }

        if let group = Self.dictionary(dictionary, "Group"), let space = Self.object(group, "CS") {
            record(resolved(PDFValue(space)))
        }
        for stream in Self.contentStreams(of: dictionary) where Self.object(stream, "F") != nil {
            faults.append(.externalContent("its content stream"))
        }

        resources = Self.inheritedResources(of: dictionary).map { [$0] } ?? []
        let content = CGPDFContentStreamCreateWithPage(page)
        scan(content)
        CGPDFContentStreamRelease(content)

        return PageContent(faults: faults, colorSpaces: colorSpaces)
    }

    // MARK: - Private
    private static func walker(_ info: UnsafeMutableRawPointer?) -> PageContentWalker? {
        info.map { Unmanaged<PageContentWalker>.fromOpaque($0).takeUnretainedValue() }
    }

    private static func operatorTable() -> CGPDFOperatorTableRef? {
        guard let table = CGPDFOperatorTableCreate() else { return nil }
        let set = { (name: String, callback: CGPDFOperatorCallback) in CGPDFOperatorTableSetCallback(table, name, callback) }

        set("q") { _, info in PageContentWalker.walker(info)?.save() }
        set("Q") { _, info in PageContentWalker.walker(info)?.restore() }
        set("Tf") { scanner, info in PageContentWalker.walker(info)?.setFont(scanner) }
        set("Tr") { scanner, info in PageContentWalker.walker(info)?.setRenderMode(scanner) }
        set("Tj") { _, info in PageContentWalker.walker(info)?.showText() }
        set("TJ") { _, info in PageContentWalker.walker(info)?.showText() }
        set("'") { _, info in PageContentWalker.walker(info)?.showText() }
        set("\"") { _, info in PageContentWalker.walker(info)?.showText() }
        set("cs") { scanner, info in PageContentWalker.walker(info)?.setSpace(scanner, isFill: true) }
        set("CS") { scanner, info in PageContentWalker.walker(info)?.setSpace(scanner, isFill: false) }
        set("scn") { scanner, info in PageContentWalker.walker(info)?.setPattern(scanner, isFill: true) }
        set("SCN") { scanner, info in PageContentWalker.walker(info)?.setPattern(scanner, isFill: false) }
        set("g") { _, info in PageContentWalker.walker(info)?.setDevice("DeviceGray", isFill: true) }
        set("G") { _, info in PageContentWalker.walker(info)?.setDevice("DeviceGray", isFill: false) }
        set("rg") { _, info in PageContentWalker.walker(info)?.setDevice("DeviceRGB", isFill: true) }
        set("RG") { _, info in PageContentWalker.walker(info)?.setDevice("DeviceRGB", isFill: false) }
        set("k") { _, info in PageContentWalker.walker(info)?.setDevice("DeviceCMYK", isFill: true) }
        set("K") { _, info in PageContentWalker.walker(info)?.setDevice("DeviceCMYK", isFill: false) }
        for name in ["f", "F", "f*"] {
            set(name) { _, info in PageContentWalker.walker(info)?.paint(fills: true, strokes: false) }
        }
        for name in ["S", "s"] {
            set(name) { _, info in PageContentWalker.walker(info)?.paint(fills: false, strokes: true) }
        }
        for name in ["B", "B*", "b", "b*"] {
            set(name) { _, info in PageContentWalker.walker(info)?.paint(fills: true, strokes: true) }
        }
        set("sh") { scanner, info in PageContentWalker.walker(info)?.paintShading(scanner) }
        set("Do") { scanner, info in PageContentWalker.walker(info)?.drawObject(scanner) }
        set("EI") { scanner, info in PageContentWalker.walker(info)?.drawInlineImage(scanner) }
        set("gs") { scanner, info in PageContentWalker.walker(info)?.setGraphicsState(scanner) }

        return table
    }

    private func scan(_ content: CGPDFContentStreamRef) {
        guard let operators else { return }
        contentStreams.append(content)
        let scanner = CGPDFScannerCreate(content, operators, Unmanaged.passUnretained(self).toOpaque())
        CGPDFScannerScan(scanner)
        CGPDFScannerRelease(scanner)
        contentStreams.removeLast()
    }

    // Scans `stream` with `streamResources`, or the resources in force where it has none, in a copy of the graphics
    // state in force, which no `Q` in it restores past. A stream is scanned once for each `ContentStreamScan`.
    private func scan(
        _ stream: CGPDFStreamRef,
        resources streamResources: CGPDFDictionaryRef?
    ) {
        guard
            let dictionary = CGPDFStreamGetDictionary(stream),
            let streamResources = streamResources ?? resources.last,
            let parent = contentStreams.last
        else {
            return
        }
        let current = state
        let context = ContentStreamScan(
            stream: dictionary,
            resources: streamResources,
            state: current,
            isUncolored: uncoloredPatternDepth > 0
        )
        guard scannedStreams.insert(context).inserted else { return }

        let base = states.count
        let outerBase = stateBase
        states.append(current)
        stateBase = states.count
        resources.append(streamResources)
        let content = CGPDFContentStreamCreateWithStream(stream, streamResources, parent)
        scan(content)
        CGPDFContentStreamRelease(content)
        resources.removeLast()
        states.removeSubrange(base...)
        stateBase = outerBase
    }

    private func save() {
        states.append(state)
    }

    private func restore() {
        guard states.count > stateBase else { return }

        states.removeLast()
    }

    private func setFont(_ scanner: CGPDFScannerRef) {
        var size: CGPDFReal = 0
        var name: UnsafePointer<CChar>?
        _ = CGPDFScannerPopNumber(scanner, &size)
        guard CGPDFScannerPopName(scanner, &name), let name else { return }

        let resourceName = String(cString: name)
        let font = resource("Font", resourceName).flatMap(Self.dictionary)
        state.font = font
        state.fontName = font.flatMap { Self.name($0, "BaseFont") } ?? resourceName
    }

    private func setRenderMode(_ scanner: CGPDFScannerRef) {
        var mode: CGPDFInteger = 0
        guard CGPDFScannerPopInteger(scanner, &mode) else { return }

        state.renderMode = mode
    }

    private func showText() {
        guard state.setsGlyphs else { return }
        if let font = state.font {
            checkFont(font, named: state.fontName)
        } else {
            faults.append(.unembeddedFont(state.fontName.isEmpty ? "of no font resource" : state.fontName))
        }
        paint(fills: state.textFills, strokes: state.textStrokes)
    }

    // A Type 3 font is embedded, its glyphs procedures in the file, which are read too. A Type 0 font is embedded
    // through its descendant font's descriptor.
    private func checkFont(
        _ font: CGPDFDictionaryRef,
        named name: String
    ) {
        guard checkedFonts.insert(font).inserted else { return }

        if Self.name(font, "Subtype") == "Type3" {
            guard let procedures = Self.dictionary(font, "CharProcs") else { return }
            let glyphResources = Self.dictionary(font, "Resources")
            for (_, procedure) in Self.entries(of: procedures) {
                guard let stream = Self.stream(procedure) else { continue }
                scan(stream, resources: glyphResources)
            }

            return
        }

        var descriptor = Self.dictionary(font, "FontDescriptor")
        var descendants: CGPDFArrayRef?
        var descendant: CGPDFDictionaryRef?
        if Self.name(font, "Subtype") == "Type0",
            CGPDFDictionaryGetArray(font, "DescendantFonts", &descendants),
            let descendants,
            CGPDFArrayGetDictionary(descendants, 0, &descendant),
            let descendant
        {
            descriptor = Self.dictionary(descendant, "FontDescriptor")
        }
        let isEmbedded = descriptor.map { descriptor in
            ["FontFile", "FontFile2", "FontFile3"].contains { Self.object(descriptor, $0) != nil }
        } ?? false
        if !isEmbedded { faults.append(.unembeddedFont(name)) }
    }

    private func setSpace(
        _ scanner: CGPDFScannerRef,
        isFill: Bool
    ) {
        var name: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &name), let name else { return }

        let space = colorSpace(named: String(cString: name))
        if isFill {
            state.fill = space
            state.fillPattern = nil
        } else {
            state.stroke = space
            state.strokePattern = nil
        }
    }

    // The pattern `scn` names last, where the space is a Pattern space.
    private func setPattern(
        _ scanner: CGPDFScannerRef,
        isFill: Bool
    ) {
        guard Self.isPattern(isFill ? state.fill : state.stroke) else { return }
        var name: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &name), let name else { return }

        let pattern = resource("Pattern", String(cString: name))
        if isFill {
            state.fillPattern = pattern
        } else {
            state.strokePattern = pattern
        }
    }

    private func setDevice(
        _ name: String,
        isFill: Bool
    ) {
        let space = resolved(.name(name))
        if isFill {
            state.fill = space
        } else {
            state.stroke = space
        }
    }

    private func paint(
        fills: Bool,
        strokes: Bool
    ) {
        if fills { paint(in: state.fill, pattern: state.fillPattern) }
        if strokes { paint(in: state.stroke, pattern: state.strokePattern) }
    }

    // A Pattern space paints what its pattern draws: a tiling pattern's content, or a shading pattern's shading. An
    // uncoloured tiling pattern's content paints in the underlying space, so the colour its content sets is not drawn.
    private func paint(
        in space: PDFValue,
        pattern: CGPDFObjectRef?
    ) {
        guard Self.isPattern(space) else {
            record(space)
            return
        }
        if let base = space.arrayValue?.dropFirst().first { record(resolved(base)) }
        guard let pattern else { return }

        if let stream = Self.stream(pattern), let dictionary = CGPDFStreamGetDictionary(stream) {
            var paintType: CGPDFInteger = 1
            let isUncolored = CGPDFDictionaryGetInteger(dictionary, "PaintType", &paintType) && paintType == 2
            if isUncolored { uncoloredPatternDepth += 1 }
            scan(stream, resources: Self.dictionary(dictionary, "Resources"))
            if isUncolored { uncoloredPatternDepth -= 1 }
        } else if
            let dictionary = Self.dictionary(pattern),
            let shading = Self.object(dictionary, "Shading"),
            let shadingDictionary = Self.dictionary(shading) ?? Self.stream(shading).flatMap(CGPDFStreamGetDictionary),
            let shadingSpace = Self.object(shadingDictionary, "ColorSpace")
        {
            record(resolved(PDFValue(shadingSpace)))
        }
    }

    private func paintShading(_ scanner: CGPDFScannerRef) {
        var name: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &name), let name else { return }
        guard
            let shading = resource("Shading", String(cString: name)),
            let dictionary = Self.dictionary(shading) ?? Self.stream(shading).flatMap(CGPDFStreamGetDictionary),
            let space = Self.object(dictionary, "ColorSpace")
        else {
            return
        }

        record(resolved(PDFValue(space)))
    }

    private func drawObject(_ scanner: CGPDFScannerRef) {
        var name: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &name), let name else { return }
        guard
            let object = resource("XObject", String(cString: name)),
            let stream = Self.stream(object),
            let dictionary = CGPDFStreamGetDictionary(stream)
        else {
            return
        }
        if Self.object(dictionary, "F") != nil { faults.append(.externalContent("an XObject's stream")) }

        if Self.name(dictionary, "Subtype") == "Form" {
            if Self.object(dictionary, "Ref") != nil { faults.append(.externalContent("a reference XObject")) }
            if let group = Self.dictionary(dictionary, "Group"), let space = Self.object(group, "CS") {
                record(resolved(PDFValue(space)))
            }
            scan(stream, resources: Self.dictionary(dictionary, "Resources"))
        } else {
            drawImage(dictionary, keys: ImageKeyTable.xObject)
        }
    }

    // An inline image's dictionary may abbreviate its keys and its spaces' names, and its `/F` is its filter.
    private func drawInlineImage(_ scanner: CGPDFScannerRef) {
        var stream: CGPDFStreamRef?
        guard CGPDFScannerPopStream(scanner, &stream), let stream,
            let dictionary = CGPDFStreamGetDictionary(stream)
        else {
            return
        }

        drawImage(dictionary, keys: ImageKeyTable.inline)
    }

    private func drawImage(
        _ image: CGPDFDictionaryRef,
        keys: ImageKeyTable
    ) {
        let isMask = keys.mask.contains { key in
            var value: CGPDFBoolean = 0
            return CGPDFDictionaryGetBoolean(image, key, &value) && value != 0
        }
        if isMask {
            paint(in: state.fill, pattern: state.fillPattern)
            return
        }

        guard let space = keys.colorSpace.lazy.compactMap({ Self.object(image, $0) }).first else {
            let filters = keys.filter.lazy.compactMap { Self.object(image, $0) }.first.map(PDFValue.init)
            let names = filters?.arrayValue?.compactMap(\.nameValue) ?? filters?.nameValue.map { [$0] } ?? []
            if names.contains("JPXDecode") {
                faults.append(.colorSpace("a JPEG 2000 image whose dictionary names no colour space, for which no "
                    + "formula is fixed"))
            }

            return
        }
        record(resolved(expanded(PDFValue(space))))
    }

    // A graphics state parameter dictionary may set the font, by its `/Font` [font size], and a soft mask.
    private func setGraphicsState(_ scanner: CGPDFScannerRef) {
        var name: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &name), let name else { return }
        guard let parameters = resource("ExtGState", String(cString: name)).flatMap(Self.dictionary) else { return }

        var fontEntry: CGPDFArrayRef?
        var font: CGPDFDictionaryRef?
        if CGPDFDictionaryGetArray(parameters, "Font", &fontEntry), let fontEntry,
            CGPDFArrayGetDictionary(fontEntry, 0, &font), let font
        {
            state.font = font
            state.fontName = Self.name(font, "BaseFont") ?? "of the graphics state \(String(cString: name))"
        }
        guard
            let mask = Self.dictionary(parameters, "SMask"),
            let group = Self.object(mask, "G").flatMap(Self.stream),
            let groupDictionary = CGPDFStreamGetDictionary(group)
        else {
            return
        }

        if let groupEntry = Self.dictionary(groupDictionary, "Group"),
            let space = Self.object(groupEntry, "CS")
        {
            record(resolved(PDFValue(space)))
        }
        scan(group, resources: Self.dictionary(groupDictionary, "Resources"))
    }

    private func record(_ space: PDFValue) {
        guard uncoloredPatternDepth == 0, seenColorSpaces.insert(space).inserted else { return }

        colorSpaces.append(space)
    }

    // The space `cs` names: a family's name, or a colour space resource.
    private func colorSpace(named name: String) -> PDFValue {
        if Self.deviceSpaces[name] != nil || name == "Pattern" { return resolved(.name(name)) }
        guard let object = resource("ColorSpace", name) else { return .name(name) }

        return resolved(PDFValue(object))
    }

    // A device space as the default space the resources in force name for it, where they name one.
    private func resolved(_ space: PDFValue) -> PDFValue {
        guard
            let name = space.nameValue,
            let defaultName = Self.deviceSpaces[name],
            let replacement = resource("ColorSpace", defaultName)
        else {
            return space
        }

        return PDFValue(replacement)
    }

    // An inline image's space with its abbreviated names written out, or the colour space resource it names.
    private func expanded(_ space: PDFValue) -> PDFValue {
        if let name = space.nameValue {
            if let full = Self.abbreviatedSpaces[name] { return .name(full) }
            if Self.deviceSpaces[name] != nil { return space }

            return resource("ColorSpace", name).map(PDFValue.init) ?? space
        }
        guard var elements = space.arrayValue, let family = elements.first?.nameValue else { return space }
        if let full = Self.abbreviatedSpaces[family] { elements[0] = .name(full) }
        if elements.count > 1 { elements[1] = expanded(elements[1]) }

        return .array(elements)
    }

    private func resource(
        _ category: String,
        _ name: String
    ) -> CGPDFObjectRef? {
        guard let current = resources.last, let entries = Self.dictionary(current, category) else { return nil }

        return Self.object(entries, name)
    }

    private static func isPattern(_ space: PDFValue) -> Bool {
        space.nameValue == "Pattern" || space.arrayValue?.first?.nameValue == "Pattern"
    }

    // The page's resources, or the nearest a parent in its page tree holds.
    private static func inheritedResources(of page: CGPDFDictionaryRef) -> CGPDFDictionaryRef? {
        var node: CGPDFDictionaryRef? = page
        var depth = 0
        while let current = node, depth < 64 {
            if let found = dictionary(current, "Resources") { return found }
            node = dictionary(current, "Parent")
            depth += 1
        }

        return nil
    }

    private static func contentStreams(of page: CGPDFDictionaryRef) -> [CGPDFDictionaryRef] {
        guard let contents = object(page, "Contents") else { return [] }
        if let single = stream(contents).flatMap(CGPDFStreamGetDictionary) { return [single] }
        var array: CGPDFArrayRef?
        guard CGPDFObjectGetValue(contents, .array, &array), let array else { return [] }

        return (0..<CGPDFArrayGetCount(array)).compactMap { index in
            var element: CGPDFStreamRef?
            guard CGPDFArrayGetStream(array, index, &element), let element else { return nil }

            return CGPDFStreamGetDictionary(element)
        }
    }

    private static func entries(of dictionary: CGPDFDictionaryRef) -> [(String, CGPDFObjectRef)] {
        var collected: [(String, CGPDFObjectRef)] = []
        CGPDFDictionaryApplyBlock(dictionary, { key, object, _ in
            collected.append((String(cString: key), object))

            return true
        }, nil)

        return collected
    }

    private static func object(
        _ dictionary: CGPDFDictionaryRef,
        _ key: String
    ) -> CGPDFObjectRef? {
        var object: CGPDFObjectRef?
        return CGPDFDictionaryGetObject(dictionary, key, &object) ? object : nil
    }

    private static func dictionary(
        _ dictionary: CGPDFDictionaryRef,
        _ key: String
    ) -> CGPDFDictionaryRef? {
        var value: CGPDFDictionaryRef?
        return CGPDFDictionaryGetDictionary(dictionary, key, &value) ? value : nil
    }

    private static func dictionary(_ object: CGPDFObjectRef) -> CGPDFDictionaryRef? {
        var value: CGPDFDictionaryRef?
        return CGPDFObjectGetValue(object, .dictionary, &value) ? value : nil
    }

    private static func stream(_ object: CGPDFObjectRef) -> CGPDFStreamRef? {
        var value: CGPDFStreamRef?
        return CGPDFObjectGetValue(object, .stream, &value) ? value : nil
    }

    private static func name(
        _ dictionary: CGPDFDictionaryRef,
        _ key: String
    ) -> String? {
        var value: UnsafePointer<CChar>?
        return CGPDFDictionaryGetName(dictionary, key, &value) ? value.map { String(cString: $0) } : nil
    }
}
