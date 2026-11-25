//
//  MatteApplierTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import FramesTestMedia
import Testing

@Suite("MatteApplier Tests")
struct MatteApplierTests {
    // MARK: - Property
    // The matte's four bands of grey from left to right, in 8-bit steps.
    private static let levels = [0.0, 64, 128, 255]

    private let directory: TemporaryDirectory

    // MARK: - Initializer
    init() throws {
        directory = try TemporaryDirectory()
    }

    // MARK: - Test
    @Test(
        "the picture's alpha is multiplied by clamp((p (1 + s) - L) / s, 0, 1) of the matte stretched over it, L its encoded luma in either form",
        arguments: [
            (0.0, 0.0, false, Compositing.encoded),
            (1.0, 0.0, false, .encoded),
            (0.5, 0.0, false, .encoded),
            (0.5, 0.2, false, .encoded),
            (0.5, 0.2, true, .encoded),
            (0.5, 0.2, false, .linear),
            (0.5, 0.2, true, .linear)
        ]
    )
    func masksByLuma(progress: Double, softness: Double, isInverted: Bool, compositing: Compositing) throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try white()),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 40, height: 10),
            matte: PictureMatte(frame: try bands(), progress: progress, softness: softness, isInverted: isInverted)
        )
        let list = DisplayList(
            size: Size(width: 40, height: 10),
            background: Color(written: "#00000000"),
            compositing: compositing,
            seed: 0,
            items: [DisplayItem(content: .picture(picture))]
        )

        // When
        let bitmap = try sut.bitmap(of: list)

        // Then
        for (band, level) in Self.levels.enumerated() {
            let luma = isInverted ? 1 - level / 255 : level / 255
            let expected = shown(luma: luma, progress: progress, softness: softness)
            let alpha = bitmap.pixel(x: band * 10 + 5, y: 5)[3]
            #expect(abs(alpha - expected) <= 1.0 / 255, "band \(band): \(alpha) is not \(expected)")
        }
    }

    @Test("a transition matte with alpha weighs by the luma of its colour over black, its transparent part as black")
    func weighsAlphaOverBlack() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let path = directory.file("alpha.png")
        try ImageWriter(size: Size(width: 20, height: 10)).write(to: path) { canvas in
            canvas.context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.5))
            canvas.context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let picture = PictureItem(
            source: .media(try white()),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 20, height: 10),
            matte: PictureMatte(frame: frame(at: path), progress: 0.75, softness: 0, isInverted: false)
        )
        let list = DisplayList(
            size: Size(width: 20, height: 10),
            background: Color(written: "#00000000"),
            seed: 0,
            items: [DisplayItem(content: .picture(picture))]
        )

        // When
        let bitmap = try sut.bitmap(of: list)

        // Then
        for x in [5, 15] {
            let alpha = bitmap.pixel(x: x, y: 5)[3]
            #expect(abs(alpha - 1) <= 1.0 / 255, "column \(x): \(alpha) is not 1")
        }
    }

    @Test("a transition matte stretched over the picture keeps its value out to the destination's edge off the pixel grid")
    func stretchesToEdge() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let path = directory.file("opaque.png")
        try ImageWriter(size: Size(width: 10, height: 5)).write(to: path) { canvas in
            canvas.fill(red: 255, green: 255, blue: 255)
        }
        // At a softness of 1 and a progress of 0.5 the alpha is 1 - L. The destination's right and bottom edges lie
        // inside a pixel, so the matte's stretched edge does too.
        let picture = PictureItem(
            source: .media(try white()),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 38.5, height: 18.5),
            matte: PictureMatte(frame: frame(at: path), progress: 0.5, softness: 1, isInverted: false)
        )
        let list = DisplayList(
            size: Size(width: 40, height: 20),
            background: Color(written: "#00000000"),
            seed: 0,
            items: [DisplayItem(content: .picture(picture))]
        )

        // When
        let bitmap = try sut.bitmap(of: list)

        // Then
        // The outermost pixels the destination covers whole.
        let edge = (0 ..< 38).flatMap { [($0, 0), ($0, 17)] } + (0 ..< 18).flatMap { [(0, $0), (37, $0)] }
        for (x, y) in edge {
            let alpha = bitmap.pixel(x: x, y: y)[3]
            #expect(alpha <= 1.0 / 255, "(\(x), \(y)): L is \(1 - alpha), not 1")
        }
    }

    @Test("a transition matte is read as an analysis picture in its source's colour space")
    func readsAnalysisPicture() throws {
        // Given
        let decoder = ReadingDecoder()
        let sut = QuartzRenderer(decoder: decoder)
        let matte = MediaFrame(media: pinned(at: "/matte.png"), index: 0, reading: .analysis(colorSpace: .rec2100PQ))
        let picture = PictureItem(
            source: .media(MediaFrame(media: pinned(at: "/picture.png"), index: 0)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 4, height: 4),
            matte: PictureMatte(frame: matte, progress: 0.5, softness: 0, isInverted: false)
        )
        let list = DisplayList(
            size: Size(width: 4, height: 4),
            background: Color(written: "#00000000"),
            seed: 0,
            items: [DisplayItem(content: .picture(picture))]
        )

        // When
        _ = try sut.bitmap(of: list)

        // Then
        #expect(decoder.readings(of: "/matte.png") == [.analysis(colorSpace: .rec2100PQ)])
    }

    // MARK: - Private
    // The expected alpha, and at softness 0 the limit of the formula as the softness goes to 0.
    private func shown(
        luma: Double,
        progress: Double,
        softness: Double
    ) -> Double {
        guard softness > 0 else { return luma < progress ? 1 : (luma > progress ? 0 : progress) }

        return min(max((progress * (1 + softness) - luma) / softness, 0), 1)
    }

    private func white() throws -> MediaFrame {
        let path = directory.file("white.png")
        try ImageWriter(size: Size(width: 40, height: 10)).write(to: path) { canvas in
            canvas.fill(red: 255, green: 255, blue: 255)
        }

        return frame(at: path)
    }

    // Half the picture's size, so it is stretched twice over.
    private func bands() throws -> MediaFrame {
        let path = directory.file("matte.png")
        try ImageWriter(size: Size(width: 20, height: 5)).write(to: path) { canvas in
            for (band, level) in Self.levels.enumerated() {
                let rectangle = Rectangle(x: Double(band) * 5, y: 0, width: 5, height: 5)
                canvas.fill(rectangle, red: level, green: level, blue: level)
            }
        }

        return frame(at: path)
    }

    private func frame(at path: String) -> MediaFrame {
        MediaFrame(media: pinned(at: path), index: 0)
    }

    private func pinned(at path: String) -> PinnedMedia {
        PinnedMedia(source: .file(PinnedFile(path: path, sha256: ""), frameTimes: nil))
    }
}
