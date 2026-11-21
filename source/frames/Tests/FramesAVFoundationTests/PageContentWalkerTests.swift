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

// What the walk of a page reads as drawn (FRAMES-3 PDF pages): by operators and their state, not by geometry.
@Suite("PageContentWalker Tests")
struct PageContentWalkerTests {
    // MARK: - Property
    private let fonts: [String: PDFValue] = ["Font": .dictionary(["F1": PageFile.helvetica, "F2": PageFile.embedded])]

    // MARK: - Initializer
    // MARK: - Test
    @Test("drawn text in a font the file does not embed is a fault, and one in an embedded font is not")
    func findsUnembeddedFont() {
        // Given
        let page = PageFile.page("BT /F2 12 Tf 10 10 Td (a) Tj /F1 12 Tf (b) Tj ET", resources: fonts)

        // When
        let content = walked(page)

        // Then
        #expect(content.faults == [.unembeddedFont("Helvetica")])
    }

    @Test("text in rendering mode 3 sets no glyph, so its font is not checked, and the mode lasts past ET to Q")
    func skipsInvisibleText() {
        // Given
        let page = PageFile.page("q 3 Tr BT /F1 12 Tf (a) Tj ET BT (b) Tj ET Q", resources: fonts)

        // When
        let content = walked(page)

        // Then
        #expect(content.faults.isEmpty)
    }

    @Test("text outside the crop box is drawn in this sense, so its font is checked")
    func checksTextOutsideCropBox() {
        // Given
        let page = PageFile.page(
            "BT /F1 12 Tf 350 280 Td (slug) Tj ET",
            resources: fonts,
            entries: ["CropBox": .array([0, 0, 100, 100].map(PDFValue.integer))]
        )

        // When
        let content = walked(page)

        // Then
        #expect(content.faults == [.unembeddedFont("Helvetica")])
    }

    @Test("content the default optional content configuration turns off is not checked, and content it shows is")
    func skipsHiddenOptionalContent() {
        // Given
        var writer = PDFFileWriter()
        let hidden = writer.add(.dictionary(["Type": .name("OCG"), "Name": .string(Data("hidden".utf8))]))
        let shown = writer.add(.dictionary(["Type": .name("OCG"), "Name": .string(Data("shown".utf8))]))
        let page = PageFile.page(
            "/OC /Hidden BDC 0 0 0 1 k 0 0 10 10 re f BT /F1 12 Tf (a) Tj ET EMC /OC /Shown BDC 1 0 0 rg 0 0 5 5 re f EMC",
            resources: fonts.merging(["Properties": .dictionary(["Hidden": hidden, "Shown": shown])]) { first, _ in first }
        )
        let catalog: [String: PDFValue] = ["OCProperties": .dictionary([
            "OCGs": .array([hidden, shown]),
            "D": .dictionary(["OFF": .array([hidden])])
        ])]

        // When
        let content = walked(page, catalog: catalog, writer: writer)

        // Then
        #expect(content.faults.isEmpty)
        #expect(content.colorSpaces == [.name("DeviceRGB")])
    }

    @Test("annotations are not read, so a font only an appearance stream sets is not checked")
    func skipsAnnotations() {
        // Given
        let appearance = PDFValue.stream(
            ["Subtype": .name("Form"), "BBox": .array([0, 0, 50, 20].map(PDFValue.integer)), "Resources": .dictionary(fonts)],
            Data("BT /F1 12 Tf (note) Tj ET".utf8)
        )
        let annotation = PDFValue.dictionary([
            "Type": .name("Annot"),
            "Subtype": .name("FreeText"),
            "Rect": .array([0, 0, 50, 20].map(PDFValue.integer)),
            "AP": .dictionary(["N": appearance])
        ])
        let page = PageFile.page("0 g 0 0 10 10 re f", entries: ["Annots": .array([annotation])])

        // When
        let content = walked(page)

        // Then
        #expect(content.faults.isEmpty)
    }

    @Test("a form XObject's stream with /F and a reference XObject are content another file holds")
    func findsExternalContent() {
        // Given
        let external = PDFValue.stream(
            ["Subtype": .name("Form"), "BBox": .array([0, 0, 10, 10].map(PDFValue.integer)), "F": .string(Data("other.pdf".utf8))],
            Data()
        )
        let reference = PDFValue.stream(
            [
                "Subtype": .name("Form"),
                "BBox": .array([0, 0, 10, 10].map(PDFValue.integer)),
                "Ref": .dictionary(["F": .string(Data("other.pdf".utf8)), "Page": .integer(0)])
            ],
            Data()
        )
        let page = PageFile.page("/X1 Do /X2 Do", resources: ["XObject": .dictionary(["X1": external, "X2": reference])])

        // When
        let content = walked(page)

        // Then
        #expect(content.faults == [.externalContent("an XObject's stream"), .externalContent("a reference XObject")])
    }

    @Test("a device space under a default space is that default space, where the resources in force name one")
    func readsDefaultSpace() {
        // Given
        let calibrated = PDFValue.array([.name("CalGray"), .dictionary(["WhitePoint": .array([.real(0.9642), .integer(1), .real(0.8249)])])])
        let page = PageFile.page("0.5 g 0 0 10 10 re f 1 0 0 rg 0 0 5 5 re f", resources: ["ColorSpace": .dictionary(["DefaultGray": calibrated])])

        // When
        let content = walked(page)

        // Then
        #expect(content.colorSpaces == [calibrated, .name("DeviceRGB")])
    }

    @Test("a form's group space, a soft mask group's space and an inline image's abbreviated space are drawn spaces")
    func findsBlendingAndImageSpaces() {
        // Given
        let form = PDFValue.stream(
            [
                "Subtype": .name("Form"),
                "BBox": .array([0, 0, 10, 10].map(PDFValue.integer)),
                "Group": .dictionary(["S": .name("Transparency"), "CS": .name("DeviceCMYK")])
            ],
            Data("1 0 0 rg 0 0 5 5 re f".utf8)
        )
        let mask = PDFValue.stream(
            [
                "Subtype": .name("Form"),
                "BBox": .array([0, 0, 10, 10].map(PDFValue.integer)),
                "Group": .dictionary(["S": .name("Transparency"), "CS": .name("Lab")])
            ],
            Data("1 g 0 0 10 10 re f".utf8)
        )
        let state = PDFValue.dictionary(["SMask": .dictionary(["S": .name("Luminosity"), "G": mask])])
        let page = PageFile.page(
            "/X1 Do q /S1 gs 0 0 10 10 re f Q BI /W 1 /H 1 /BPC 8 /CS /CMYK ID \u{0}\u{0}\u{0}\u{0} EI",
            resources: ["XObject": .dictionary(["X1": form]), "ExtGState": .dictionary(["S1": state])]
        )

        // When
        let content = walked(page)

        // Then
        #expect(content.colorSpaces.contains(.name("DeviceCMYK")))
        #expect(content.colorSpaces.contains(.name("Lab")))
        #expect(content.colorSpaces.contains(.name("DeviceRGB")))
    }

    @Test("a JPEG 2000 image whose dictionary names no colour space is a fault")
    func findsJPXWithoutSpace() {
        // Given
        let image = PDFValue.stream(
            ["Subtype": .name("Image"), "Width": .integer(1), "Height": .integer(1), "Filter": .name("JPXDecode")],
            Data()
        )
        let page = PageFile.page("/I1 Do", resources: ["XObject": .dictionary(["I1": image])])

        // When
        let content = walked(page)

        // Then
        #expect(content.faults.count == 1)
    }

    // MARK: - Private
    private func walked(
        _ page: [String: PDFValue],
        catalog: [String: PDFValue] = [:],
        writer: PDFFileWriter = PDFFileWriter()
    ) -> PageContent {
        let file = PDFFileWriter.document(pages: [page], catalog: catalog, writer: writer)
        guard
            let provider = CGDataProvider(data: file as CFData),
            let document = CGPDFDocument(provider),
            let pdfPage = document.page(at: 1)
        else {
            return PageContent(faults: [.size(.init(width: 0, height: 0))], colorSpaces: [])
        }

        return PageContentWalker(document: document).content(of: pdfPage)
    }
}
