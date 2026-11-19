//
//  MatteApplierTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

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
        let bitmap = try sut.frame(of: list)

        // Then
        for (band, level) in Self.levels.enumerated() {
            let luma = isInverted ? 1 - level / 255 : level / 255
            let expected = shown(luma: luma, progress: progress, softness: softness)
            let alpha = bitmap.pixel(x: band * 10 + 5, y: 5)[3]
            #expect(abs(alpha - expected) <= 1.0 / 255, "band \(band): \(alpha) is not \(expected)")
        }
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
        MediaFrame(media: PinnedMedia(source: .file(PinnedFile(path: path, sha256: ""))), index: 0)
    }
}
