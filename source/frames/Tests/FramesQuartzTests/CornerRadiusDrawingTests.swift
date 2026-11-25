//
//  CornerRadiusDrawingTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/24/26.
//

import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import FramesTestMedia
import Testing

// A box from (10, 10) to (90, 90) on a 100 x 100 output, its corners `[0, 10, 20, 40]` in the order top left, top right,
// bottom right, bottom left (FRAMES-20). A pixel d to d + 1 in from a corner along both sides lies wholly outside an
// arc of radius r where (r - d - 1) √2 > r, and wholly inside it where (r - d) √2 < r, so each corner is told by a
// pixel it cuts off and one it keeps.
@Suite("Corner radius drawing Tests")
struct CornerRadiusDrawingTests {
    // MARK: - Property
    private static let box = Rectangle(x: 10, y: 10, width: 80, height: 80)
    private static let corners = CornerRadii(topLeft: 0, topRight: 10, bottomRight: 20, bottomLeft: 40)
    // Pixels the corners cut off and pixels they keep: the top left one square, then 1 to 2 and 4 to 5 in from the
    // top right, 3 to 4 and 8 to 9 from the bottom right, and 8 to 9 and 14 to 15 from the bottom left.
    private static let cutOff = [(88, 11), (86, 86), (18, 81)]
    private static let kept = [(10, 10), (85, 14), (81, 81), (24, 75)]

    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())
    private let directory: TemporaryDirectory

    // MARK: - Initializer
    init() throws {
        directory = try TemporaryDirectory()
    }

    // MARK: - Test
    @Test("a filled rect rounds each corner by its own radius")
    func roundsEachCornerOfRect() throws {
        // Given
        let rect = PathItem(geometry: .rect(Self.box, radius: Self.corners), fill: .color(Color(written: "#000000")), stroke: nil)

        // When
        let bitmap = try sut.frame(of: list(items: [DisplayItem(content: .path(rect))]))

        // Then
        expect(bitmap, at: Self.cutOff, inked: false)
        expect(bitmap, at: Self.kept, inked: true)
    }

    @Test("a rect mask rounds each corner by its own radius")
    func roundsEachCornerOfMask() throws {
        // Given
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 100, height: 100), color: Color(written: "#FFFFFF"))
        let mask = ItemMask(geometry: .rect(Self.box, radius: Self.corners), transform: .identity, feather: 0, isInverted: false, mode: .add)

        // When
        let bitmap = try sut.frame(of: list(items: [DisplayItem(mask: [mask], content: .path(fill))]))

        // Then
        expect(bitmap, at: Self.cutOff, inked: false)
        expect(bitmap, at: Self.kept, inked: true)
    }

    // The 4 wide border outside the picture lies from each corner's radius to that radius plus 4 about the corner's
    // centre, and square about the top left corner. At the bottom left, about (50, 50), pixel (20, 79) lies from 41 to
    // 42.4 from it, inside the border, and pixel (16, 83) past 46.
    @Test("a picture rounds each corner by its own radius, and a border outside it each corner by that radius plus its width")
    func roundsEachCornerOfPictureAndBorder() throws {
        // Given
        let picture = PictureItem(
            source: .media(try white(size: 80)),
            rectangle: nil,
            destination: Self.box,
            radius: Self.corners,
            border: MediaBorder(width: 4, color: Color(written: "#FF0000"), align: .outside)
        )

        // When
        let bitmap = try sut.frame(of: list(items: [DisplayItem(content: .picture(picture))]))

        // Then
        #expect(bitmap.pixel(x: 7, y: 7) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 10, y: 10) == [1, 1, 1, 1])
        #expect(bitmap.pixel(x: 85, y: 14) == [1, 1, 1, 1])
        #expect(bitmap.pixel(x: 81, y: 81) == [1, 1, 1, 1])
        #expect(bitmap.pixel(x: 24, y: 75) == [1, 1, 1, 1])
        #expect(bitmap.pixel(x: 20, y: 79) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 16, y: 83)[3] == 0)
    }

    // The top side's radii add up to 120 over its 80, and the left side's to 90, so every radius is scaled by 2 / 3,
    // to 60 at the top left and 20 at the top right. Cut one by one to half the shorter side they would be 40 and 30:
    // pixel (24, 24), 14 to 15 in from the top left, is outside an arc of 60 and inside one of 40, and pixel (82, 17),
    // 7 to 8 in from the top right, inside an arc of 20 and outside one of 30.
    @Test("radii whose corners overlap along a side are all scaled by one factor, keeping their proportions")
    func scalesOverlappingCornersByOneFactor() throws {
        // Given
        let radius = CornerRadii(topLeft: 90, topRight: 30, bottomRight: 0, bottomLeft: 0)
        let rect = PathItem(geometry: .rect(Self.box, radius: radius), fill: .color(Color(written: "#000000")), stroke: nil)

        // When
        let bitmap = try sut.frame(of: list(items: [DisplayItem(content: .path(rect))]))

        // Then
        expect(bitmap, at: [(24, 24)], inked: false)
        expect(bitmap, at: [(82, 17), (88, 88), (10, 88)], inked: true)
    }

    // MARK: - Private
    private func list(items: [DisplayItem]) -> DisplayList {
        DisplayList(size: Size(width: 100, height: 100), background: Color(written: "#00000000"), seed: 0, items: items)
    }

    private func white(size: Double) throws -> MediaFrame {
        let path = directory.file("white-\(Int(size)).png")
        try ImageWriter(size: Size(width: size, height: size)).write(to: path) { canvas in
            canvas.fill(red: 255, green: 255, blue: 255)
        }

        return MediaFrame(media: PinnedMedia(source: .file(PinnedFile(path: path, sha256: ""), frameTimes: nil)), index: 0)
    }

    private func expect(
        _ bitmap: Bitmap,
        at pixels: [(Int, Int)],
        inked: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for (x, y) in pixels {
            let alpha = bitmap.pixel(x: x, y: y)[3]
            #expect(
                inked ? alpha > 0.99 : alpha < 0.01,
                "pixel (\(x), \(y)) has alpha \(alpha), expected \(inked ? "inked" : "blank")",
                sourceLocation: sourceLocation
            )
        }
    }
}
