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
// inline images included, against the resources each is drawn with, the page's own or those it inherits. Every
// operator is read, whatever optional content shows, and no annotation is. A font counts where text that sets glyphs
// is set in it, and a colour space where content sets it, or draws an image, a shading or a transparency group in it.
// A Core Graphics operator callback is a C function, told nothing of its operator, so each operator has its own.
final class PageContentWalker {
    // MARK: - Property
    // How deep a colour space is followed through its base spaces; one deeper is no untagged colour.
    private static let depthLimit = 8

    private var states = [PageGraphicsState()]
    // The fewest states the stream read now holds: its own first state is the last a `Q` in it restores to.
    private var stateBase = 1
    private var resources: [CGPDFDictionaryRef] = []
    private var contentStreams: [CGPDFContentStreamRef] = []
    private var scannedStreams: Set<ContentStreamScan> = []
    private var checkedFonts: Set<CGPDFDictionaryRef> = []
    private var operators: CGPDFOperatorTableRef?
    private var unembeddedFont: String?
    private var drawsOnlyUntaggedColor = true

    private var state: PageGraphicsState {
        get { states[states.count - 1] }
        set { states[states.count - 1] = newValue }
    }

    // MARK: - Initializer
    // MARK: - Public
    func content(of page: CGPDFPage) -> PageContent {
        if let dictionary = page.dictionary {
            operators = Self.operatorTable()
            defer { operators.map(CGPDFOperatorTableRelease) }

            resources = Self.inheritedResources(of: dictionary).map { [$0] } ?? []
            drawGroup(of: dictionary)
            let content = CGPDFContentStreamCreateWithPage(page)
            scan(content)
            CGPDFContentStreamRelease(content)
        }

        return PageContent(unembeddedFont: unembeddedFont, drawsOnlyUntaggedColor: drawsOnlyUntaggedColor)
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
        set("cs") { scanner, info in PageContentWalker.walker(info)?.setColorSpace(scanner) }
        set("CS") { scanner, info in PageContentWalker.walker(info)?.setColorSpace(scanner) }
        set("scn") { scanner, info in PageContentWalker.walker(info)?.setPattern(scanner) }
        set("SCN") { scanner, info in PageContentWalker.walker(info)?.setPattern(scanner) }
        set("g") { _, info in PageContentWalker.walker(info)?.draws(inNamed: "DeviceGray") }
        set("G") { _, info in PageContentWalker.walker(info)?.draws(inNamed: "DeviceGray") }
        set("rg") { _, info in PageContentWalker.walker(info)?.draws(inNamed: "DeviceRGB") }
        set("RG") { _, info in PageContentWalker.walker(info)?.draws(inNamed: "DeviceRGB") }
        set("k") { _, info in PageContentWalker.walker(info)?.draws(inNamed: "DeviceCMYK") }
        set("K") { _, info in PageContentWalker.walker(info)?.draws(inNamed: "DeviceCMYK") }
        set("sh") { scanner, info in PageContentWalker.walker(info)?.drawShading(scanner) }
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
        let scan = ContentStreamScan(stream: dictionary, resources: streamResources, state: current)
        guard scannedStreams.insert(scan).inserted else { return }

        let base = states.count
        let outerBase = stateBase
        states.append(current)
        stateBase = states.count
        resources.append(streamResources)
        let content = CGPDFContentStreamCreateWithStream(stream, streamResources, parent)
        self.scan(content)
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
        guard let font = state.font else {
            found(unembeddedFont: state.fontName.isEmpty ? "of no font resource" : state.fontName)
            return
        }

        checkFont(font, named: state.fontName)
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
            for procedure in Self.values(of: procedures) {
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
        if !isEmbedded { found(unembeddedFont: name) }
    }

    private func found(unembeddedFont name: String) {
        if unembeddedFont == nil { unembeddedFont = name }
    }

    private func setColorSpace(_ scanner: CGPDFScannerRef) {
        var name: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &name), let name else { return }

        draws(inNamed: String(cString: name))
    }

    // The pattern `scn` names last, where the space is a Pattern space: a tiling pattern's content, or a shading
    // pattern's shading.
    private func setPattern(_ scanner: CGPDFScannerRef) {
        var name: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &name), let name else { return }
        guard let pattern = resource("Pattern", String(cString: name)) else { return }

        if let stream = Self.stream(pattern), let dictionary = CGPDFStreamGetDictionary(stream) {
            scan(stream, resources: Self.dictionary(dictionary, "Resources"))
        } else if let dictionary = Self.dictionary(pattern), let shading = Self.object(dictionary, "Shading") {
            draws(inShading: shading)
        }
    }

    private func drawShading(_ scanner: CGPDFScannerRef) {
        var name: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &name), let name else { return }
        guard let shading = resource("Shading", String(cString: name)) else { return }

        draws(inShading: shading)
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

        if Self.name(dictionary, "Subtype") == "Form" {
            drawGroup(of: dictionary)
            scan(stream, resources: Self.dictionary(dictionary, "Resources"))
        } else {
            drawImage(dictionary, keys: .xObject)
        }
    }

    private func drawInlineImage(_ scanner: CGPDFScannerRef) {
        var stream: CGPDFStreamRef?
        guard CGPDFScannerPopStream(scanner, &stream), let stream, let dictionary = CGPDFStreamGetDictionary(stream) else {
            return
        }

        drawImage(dictionary, keys: .inline)
    }

    // A stencil mask paints in the fill colour, whose colour space is set where the content sets it. An image whose
    // dictionary names no colour space holds it in its codestream, a JPEG 2000 image's, which is no untagged colour.
    private func drawImage(
        _ image: CGPDFDictionaryRef,
        keys: ImageKeyTable
    ) {
        let isMask = keys.mask.contains { key in
            var value: CGPDFBoolean = 0
            return CGPDFDictionaryGetBoolean(image, key, &value) && value != 0
        }
        guard !isMask else { return }

        if let space = keys.colorSpace.lazy.compactMap({ Self.object(image, $0) }).first {
            draws(in: space)
        } else {
            drawsOnlyUntaggedColor = false
        }
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

        drawGroup(of: groupDictionary)
        scan(group, resources: Self.dictionary(groupDictionary, "Resources"))
    }

    // A transparency group blends in its `/CS`.
    private func drawGroup(of dictionary: CGPDFDictionaryRef) {
        guard let group = Self.dictionary(dictionary, "Group"), let space = Self.object(group, "CS") else { return }

        draws(in: space)
    }

    private func draws(inShading shading: CGPDFObjectRef) {
        guard
            let dictionary = Self.dictionary(shading) ?? Self.stream(shading).flatMap(CGPDFStreamGetDictionary),
            let space = Self.object(dictionary, "ColorSpace")
        else {
            return
        }

        draws(in: space)
    }

    private func draws(in space: CGPDFObjectRef) {
        if !isUntagged(space, depth: 0) { drawsOnlyUntaggedColor = false }
    }

    private func draws(inNamed name: String) {
        if !isUntagged(named: name, depth: 0) { drawsOnlyUntaggedColor = false }
    }

    // Whether `space` holds the page's untagged colour: DeviceRGB or DeviceGray where the resources in force name no
    // default space for it, a Pattern space, whose patterns are read where they are named, and a Pattern, Indexed,
    // Separation or DeviceN space whose underlying, base or alternate space does.
    private func isUntagged(
        _ space: CGPDFObjectRef,
        depth: Int
    ) -> Bool {
        if let name = Self.name(space) { return isUntagged(named: name, depth: depth) }
        var array: CGPDFArrayRef?
        var family: UnsafePointer<CChar>?
        guard
            depth < Self.depthLimit,
            CGPDFObjectGetValue(space, .array, &array),
            let array,
            CGPDFArrayGetName(array, 0, &family),
            let family
        else {
            return false
        }

        let underlying: Int
        switch String(cString: family) {
        case "Pattern", "Indexed", "I":
            underlying = 1

        case "Separation", "DeviceN":
            underlying = 2

        default:
            return false
        }
        var element: CGPDFObjectRef?
        guard CGPDFArrayGetObject(array, underlying, &element), let element else {
            return String(cString: family) == "Pattern"
        }

        return isUntagged(element, depth: depth + 1)
    }

    // A family's name, an inline image's abbreviation of one, or a colour space resource's name.
    private func isUntagged(
        named name: String,
        depth: Int
    ) -> Bool {
        switch name {
        case "Pattern":
            return true

        case "DeviceRGB", "RGB":
            return resource("ColorSpace", "DefaultRGB") == nil

        case "DeviceGray", "G":
            return resource("ColorSpace", "DefaultGray") == nil

        case "DeviceCMYK", "CMYK":
            return false

        default:
            guard depth < Self.depthLimit, let space = resource("ColorSpace", name) else { return false }

            return isUntagged(space, depth: depth + 1)
        }
    }

    private func resource(
        _ category: String,
        _ name: String
    ) -> CGPDFObjectRef? {
        guard let current = resources.last, let entries = Self.dictionary(current, category) else { return nil }

        return Self.object(entries, name)
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

    private static func values(of dictionary: CGPDFDictionaryRef) -> [CGPDFObjectRef] {
        var collected: [CGPDFObjectRef] = []
        CGPDFDictionaryApplyBlock(dictionary, { _, object, _ in
            collected.append(object)

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

    private static func name(_ object: CGPDFObjectRef) -> String? {
        var value: UnsafePointer<CChar>?
        return CGPDFObjectGetValue(object, .name, &value) ? value.map { String(cString: $0) } : nil
    }
}
