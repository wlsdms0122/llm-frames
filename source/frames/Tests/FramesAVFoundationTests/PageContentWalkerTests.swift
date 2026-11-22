//
//  PageContentWalkerTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import Frames
@testable import FramesAVFoundation
import Testing

// What the walk of a page reads as drawn (FRAMES-3 PDF pages): by operators and their state, not by what is shown.
@Suite("PageContentWalker Tests")
struct PageContentWalkerTests {
    // MARK: - Property
    private static let calibrated = PDFValue.array([
        .name("CalGray"),
        .dictionary(["WhitePoint": .array([.real(0.9642), .integer(1), .real(0.8249)])])
    ])

    private let fonts: [String: PDFValue] = ["Font": .dictionary(["F1": PageFile.helvetica, "F2": PageFile.embedded])]

    // MARK: - Initializer
    // MARK: - Test
    @Test("drawn text in a font the file does not embed is found, and one in an embedded font is not")
    func findsUnembeddedFont() throws {
        // Given
        let page = PageFile.page("BT /F2 12 Tf 10 10 Td (a) Tj /F1 12 Tf (b) Tj ET", resources: fonts)

        // When
        let content = try walked(page)

        // Then
        #expect(content.unembeddedFont == "Helvetica")
    }

    @Test("text in rendering mode 3 sets no glyph, so its font is not checked, and the mode lasts past ET to Q")
    func skipsInvisibleText() throws {
        // Given
        let page = PageFile.page("q 3 Tr BT /F1 12 Tf (a) Tj ET BT (b) Tj ET Q", resources: fonts)

        // When
        let content = try walked(page)

        // Then
        #expect(content.unembeddedFont == nil)
    }

    @Test("a font a graphics state's /Font sets is the font text is set in")
    func readsGraphicsStateFont() throws {
        // Given
        let state = PDFValue.dictionary(["Font": .array([PageFile.helvetica, .integer(12)])])
        let page = PageFile.page("BT /G0 gs 10 10 Td (a) Tj ET", resources: ["ExtGState": .dictionary(["G0": state])])

        // When
        let content = try walked(page)

        // Then
        #expect(content.unembeddedFont == "Helvetica")
    }

    @Test("text outside the crop box is read, so its font is checked")
    func checksTextOutsideCropBox() throws {
        // Given
        let page = PageFile.page(
            "BT /F1 12 Tf 350 280 Td (slug) Tj ET",
            resources: fonts,
            entries: ["CropBox": .array([0, 0, 100, 100].map(PDFValue.integer))]
        )

        // When
        let content = try walked(page)

        // Then
        #expect(content.unembeddedFont == "Helvetica")
    }

    @Test("content optional content hides is read as content it shows, its fonts and colour spaces included")
    func readsHiddenOptionalContent() throws {
        // Given
        var writer = PDFFileWriter()
        let hidden = writer.add(.dictionary(["Type": .name("OCG"), "Name": .string(Data("hidden".utf8))]))
        let page = PageFile.page(
            "/OC /Hidden BDC 0 0 0 1 k 0 0 10 10 re f BT /F1 12 Tf (a) Tj ET EMC",
            resources: fonts.merging(["Properties": .dictionary(["Hidden": hidden])]) { first, _ in first }
        )
        let catalog: [String: PDFValue] = ["OCProperties": .dictionary([
            "OCGs": .array([hidden]),
            "D": .dictionary(["OFF": .array([hidden])])
        ])]

        // When
        let content = try walked(page, catalog: catalog, writer: writer)

        // Then
        #expect(content.unembeddedFont == "Helvetica")
        #expect(!content.drawsOnlyUntaggedColor)
    }

    @Test("annotations are not read, so a font and a colour space only an appearance stream sets are not found")
    func skipsAnnotations() throws {
        // Given
        let appearance = PDFValue.stream(
            ["Subtype": .name("Form"), "BBox": .array([0, 0, 50, 20].map(PDFValue.integer)), "Resources": .dictionary(fonts)],
            Data("0 0 0 1 k BT /F1 12 Tf (note) Tj ET".utf8)
        )
        let annotation = PDFValue.dictionary([
            "Type": .name("Annot"),
            "Subtype": .name("FreeText"),
            "Rect": .array([0, 0, 50, 20].map(PDFValue.integer)),
            "AP": .dictionary(["N": appearance])
        ])
        let page = PageFile.page("0 g 0 0 10 10 re f", entries: ["Annots": .array([annotation])])

        // When
        let content = try walked(page)

        // Then
        #expect(content == PageContent(unembeddedFont: nil, drawsOnlyUntaggedColor: true))
    }

    @Test(
        "DeviceRGB and DeviceGray, and the spaces over them, are the untagged colour where no default space stands for them",
        arguments: [
            ("0.5 g 1 0 0 RG 0 0 10 10 re B", [String: PDFValue](), true),
            ("/C0 cs 0 sc 0 0 10 10 re f", ["C0": .array([.name("Indexed"), .name("DeviceRGB"), .integer(0), .string(Data([255, 0, 0]))])], true),
            ("/C0 cs 1 sc 0 0 10 10 re f", ["C0": .array([.name("Separation"), .name("Spot"), .name("DeviceGray"), .dictionary([:])])], true),
            ("/Pattern cs 0 0 10 10 re f", [:], true),
            ("0.5 g 0 0 10 10 re f", ["DefaultGray": Self.calibrated], false),
            ("/C0 cs 0.5 sc 0 0 10 10 re f", ["C0": Self.calibrated], false),
            ("0 0 0 1 k 0 0 10 10 re f", [:], false),
            ("/C0 cs 0 sc 0 0 10 10 re f", ["C0": .array([.name("Indexed"), .name("DeviceCMYK"), .integer(0), .string(Data([0, 0, 0, 255]))])], false)
        ]
    )
    func readsUntaggedColor(
        operators: String,
        spaces: [String: PDFValue],
        isUntagged: Bool
    ) throws {
        // Given
        let page = PageFile.page(operators, resources: ["ColorSpace": .dictionary(spaces)])

        // When
        let content = try walked(page)

        // Then
        #expect(content.drawsOnlyUntaggedColor == isUntagged)
    }

    @Test(
        "an image, an inline image, a shading, a shading pattern and a transparency group are drawn in their colour space",
        arguments: [
            ("/I1 Do", true),
            ("/I2 Do", false),
            ("/I3 Do", false),
            ("BI /W 1 /H 1 /BPC 8 /CS /G ID \u{0} EI", true),
            ("BI /W 1 /H 1 /BPC 8 /CS /CMYK ID \u{0}\u{0}\u{0}\u{0} EI", false),
            ("BI /W 1 /H 1 /BPC 8 /CS [/I /RGB 0 <ff0000>] ID \u{0} EI", true),
            ("/Sh0 sh", false),
            ("/Pattern cs /P0 scn 0 0 10 10 re f", false),
            ("/X1 Do", false),
            ("q /S1 gs 0 0 10 10 re f Q", false)
        ]
    )
    func readsDrawnSpaces(
        operators: String,
        isUntagged: Bool
    ) throws {
        // Given
        let image = { (entries: [String: PDFValue]) in
            PDFValue.stream(
                ["Subtype": .name("Image"), "Width": .integer(1), "Height": .integer(1), "BitsPerComponent": .integer(8)]
                    .merging(entries) { _, entry in entry },
                Data([0, 0, 0])
            )
        }
        let shading = PDFValue.dictionary([
            "ShadingType": .integer(2),
            "ColorSpace": Self.calibrated,
            "Coords": .array([0, 0, 10, 0].map(PDFValue.integer)),
            "Function": .dictionary([
                "FunctionType": .integer(2),
                "Domain": .array([.integer(0), .integer(1)]),
                "N": .integer(1)
            ])
        ])
        let group = { (space: PDFValue) in
            PDFValue.stream(
                [
                    "Subtype": .name("Form"),
                    "BBox": .array([0, 0, 10, 10].map(PDFValue.integer)),
                    "Group": .dictionary(["S": .name("Transparency"), "CS": space])
                ],
                Data("1 0 0 rg 0 0 5 5 re f".utf8)
            )
        }
        let resources: [String: PDFValue] = [
            "XObject": .dictionary([
                "I1": image(["ColorSpace": .name("DeviceRGB")]),
                "I2": image(["ColorSpace": Self.calibrated]),
                "I3": image(["Filter": .name("JPXDecode")]),
                "X1": group(.name("DeviceCMYK"))
            ]),
            "Shading": .dictionary(["Sh0": shading]),
            "Pattern": .dictionary(["P0": .dictionary(["PatternType": .integer(2), "Shading": shading])]),
            "ExtGState": .dictionary(["S1": .dictionary(["SMask": .dictionary(["S": .name("Luminosity"), "G": group(.name("Lab"))])])])
        ]
        let page = PageFile.page(operators, resources: resources)

        // When
        let content = try walked(page)

        // Then
        #expect(content.drawsOnlyUntaggedColor == isUntagged)
    }

    @Test("a tiling pattern's content and a Type 3 font's glyphs are read where they are drawn")
    func readsPatternAndGlyphContent() throws {
        // Given
        let pattern = PDFValue.stream(
            [
                "PatternType": .integer(1),
                "PaintType": .integer(1),
                "TilingType": .integer(1),
                "BBox": .array([0, 0, 2, 2].map(PDFValue.integer)),
                "XStep": .integer(2),
                "YStep": .integer(2),
                "Resources": .dictionary(fonts)
            ],
            Data("BT /F1 1 Tf (a) Tj ET".utf8)
        )
        let glyphFont = PDFValue.dictionary([
            "Type": .name("Font"),
            "Subtype": .name("Type3"),
            "FontBBox": .array([0, 0, 1, 1].map(PDFValue.integer)),
            "FontMatrix": .array([.real(0.001), .integer(0), .integer(0), .real(0.001), .integer(0), .integer(0)]),
            "CharProcs": .dictionary(["a": .stream([:], Data("1000 0 d0 0 0 0 1 k 0 0 1000 1000 re f".utf8))]),
            "Encoding": .dictionary(["Differences": .array([.integer(97), .name("a")])]),
            "FirstChar": .integer(97),
            "LastChar": .integer(97),
            "Widths": .array([.integer(1000)])
        ])
        let patternPage = PageFile.page("/Pattern cs /P0 scn 0 0 10 10 re f", resources: ["Pattern": .dictionary(["P0": pattern])])
        let glyphPage = PageFile.page("BT /T3 12 Tf (a) Tj ET", resources: ["Font": .dictionary(["T3": glyphFont])])

        // When
        let patternContent = try walked(patternPage)
        let glyphContent = try walked(glyphPage)

        // Then
        #expect(patternContent.unembeddedFont == "Helvetica")
        #expect(glyphContent == PageContent(unembeddedFont: nil, drawsOnlyUntaggedColor: false))
    }

    @Test("a form drawn under two parents' resources is read under each, so the second's DeviceCMYK is found")
    func readsFormUnderEachResources() throws {
        // Given
        var writer = PDFFileWriter()
        let form = writer.add(.stream(
            ["Type": .name("XObject"), "Subtype": .name("Form"), "BBox": .array([0, 0, 10, 10].map(PDFValue.integer))],
            Data("/CS0 cs 0 0 10 10 re f".utf8)
        ))
        let parent = { (space: String) in
            PDFValue.stream(
                [
                    "Type": .name("XObject"),
                    "Subtype": .name("Form"),
                    "BBox": .array([0, 0, 10, 10].map(PDFValue.integer)),
                    "Resources": .dictionary([
                        "ColorSpace": .dictionary(["CS0": .name(space)]),
                        "XObject": .dictionary(["Fm0": form])
                    ])
                ],
                Data("/Fm0 Do".utf8)
            )
        }
        let page = PageFile.page(
            "/P1 Do /P2 Do",
            resources: ["XObject": .dictionary(["P1": parent("DeviceRGB"), "P2": parent("DeviceCMYK")])]
        )

        // When
        let content = try walked(page, writer: writer)

        // Then
        #expect(!content.drawsOnlyUntaggedColor)
    }

    @Test("a form first read in one font is read again in the font in force where it is drawn next")
    func rereadsFormInEachFont() throws {
        // Given
        let form = PDFValue.stream(
            ["Type": .name("XObject"), "Subtype": .name("Form"), "BBox": .array([0, 0, 10, 10].map(PDFValue.integer))],
            Data("BT (a) Tj ET".utf8)
        )
        let page = PageFile.page(
            "BT /F2 12 Tf ET /Fm0 Do BT /F1 12 Tf ET /Fm0 Do",
            resources: fonts.merging(["XObject": .dictionary(["Fm0": form])]) { first, _ in first }
        )

        // When
        let content = try walked(page)

        // Then
        #expect(content.unembeddedFont == "Helvetica")
    }

    @Test("a Q a nested stream does not match restores none of the state of the content that draws it")
    func keepsCallerStateOnUnmatchedRestore() throws {
        // Given
        let form = PDFValue.stream(
            ["Type": .name("XObject"), "Subtype": .name("Form"), "BBox": .array([0, 0, 10, 10].map(PDFValue.integer))],
            Data("Q Q".utf8)
        )
        let page = PageFile.page(
            "q 3 Tr /Fm0 Do BT /F1 12 Tf (a) Tj ET Q",
            resources: fonts.merging(["XObject": .dictionary(["Fm0": form])]) { first, _ in first }
        )

        // When
        let content = try walked(page)

        // Then
        #expect(content.unembeddedFont == nil)
    }

    // MARK: - Private
    private func walked(
        _ page: [String: PDFValue],
        catalog: [String: PDFValue] = [:],
        writer: PDFFileWriter = PDFFileWriter()
    ) throws -> PageContent {
        let file = PDFFileWriter.document(pages: [page], catalog: catalog, writer: writer)
        let provider = try #require(CGDataProvider(data: file as CFData))
        let document = try #require(CGPDFDocument(provider))
        let pdfPage = try #require(document.page(at: 1))

        return PageContentWalker().content(of: pdfPage)
    }
}
