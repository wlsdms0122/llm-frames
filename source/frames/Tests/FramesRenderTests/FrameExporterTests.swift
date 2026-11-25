//
//  FrameExporterTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesAVFoundation
import FramesCoreText
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// Stills, sheets and extracted frames written by `FrameExporter` on the real decoder, renderer, encoder and shaper,
// read back through the decoder. Serialized, so that the tests running at once read far fewer files with AVFoundation
// than the 64 at once at which its reads stop finishing (FRAMES-21 Notes).
@Suite("FrameExporter Tests", .serialized, .ownThread)
struct FrameExporterTests {
    // MARK: - Property
    // H.264 subsamples and compresses colour, so a flat colour comes back to within a few steps.
    private let tolerance = 16.0 / 255
    private let colors: [[Double]] = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [128, 128, 128]]
    private let orange: [Double] = [255, 128, 0]
    private let blue: [Double] = [0, 0, 255]
    private let sheetBackground: [Double] = [32, 32, 32]

    // MARK: - Initializer

    // MARK: - Test
    @Test("still draws the sequence frames at full size side by side, each with its time burnt into its top left")
    func drawsStill() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let document = try sequence(in: media)
        let face = try labelFace()
        let sut = exporter()

        // When
        try sut.still(document, at: [0.2, 0.7], labelFace: face, to: output.file("still.png"))

        // Then
        // The label size is 14 on a 160 wide frame, so frames lie 14 apart with 14 around them, and each label's
        // background starts 7 into its frame.
        let still = try picture(at: output.file("still.png"))
        #expect(still.width == 14 + 160 + 14 + 160 + 14)
        #expect(still.height == 14 + 90 + 14)
        #expect(still.isPixel(x: 5, y: 5, sheetBackground, tolerance: 1.0 / 255))
        #expect(still.isPixel(x: 94, y: 59, orange, tolerance: 1.0 / 255))
        #expect(still.isPixel(x: 268, y: 59, blue, tolerance: 1.0 / 255))
        #expect(still.isPixel(x: 22, y: 33, labelled(orange), tolerance: 2.0 / 255))
        #expect(still.isPixel(x: 20, y: 33, orange, tolerance: 1.0 / 255))
        #expect(still.isPixel(x: 30, y: 20, orange, tolerance: 1.0 / 255))
        #expect(pixels(in: still, x: 21..<80, y: 21..<46, [255, 255, 255], tolerance: 2.0 / 255) > 0)
        #expect(pixels(in: still, x: 195..<254, y: 21..<46, labelled(blue), tolerance: 2.0 / 255) > 0)
        #expect(pixels(in: still, x: 195..<254, y: 21..<46, [255, 255, 255], tolerance: 2.0 / 255) > 0)
        #expect(try contents(of: output) == ["still.png"])
    }

    @Test("a document's theme does not change how still labels its frames")
    func labelsWithoutTheme() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let plain = try sequence(in: media)
        let themed = try sequence(
            in: media,
            theme: #"""
                { "font": ["Helvetica"], "colors": { "accent": "#00FF00", "background": "#0000FF", "text": "#FF00FF" } }
                """#
        )
        let face = try labelFace()
        let sut = exporter()

        // When
        try sut.still(plain, at: [0.2], labelFace: face, to: output.file("plain.png"))
        try sut.still(themed, at: [0.2], labelFace: face, to: output.file("themed.png"))

        // Then
        #expect(try picture(at: output.file("plain.png")) == picture(at: output.file("themed.png")))
    }

    @Test("sheet lays a video's frames out on a grid, each cell at most 480 pixels on its longer side")
    func drawsVideoSheet() async throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let video = try await self.video(in: media)
        let face = try labelFace()
        let sut = exporter()

        // When
        try sut.sheet(
            .video(path: video),
            range: FrameRange(),
            columns: 2,
            labelFace: face,
            to: output.file("sheet.png")
        )

        // Then
        // 640 x 360 cells shrink to 480 x 270, where the label size is 14.
        let sheet = try picture(at: output.file("sheet.png"))
        let centres = [(254, 149), (748, 149), (254, 433), (748, 433)]
        #expect(sheet.width == 14 + 480 + 14 + 480 + 14)
        #expect(sheet.height == 14 + 270 + 14 + 270 + 14)
        for (index, centre) in centres.enumerated() {
            #expect(
                sheet.isPixel(x: centre.0, y: centre.1, colors[index], tolerance: tolerance),
                "cell \(index): \(sheet.pixel(x: centre.0, y: centre.1))"
            )
        }
        #expect(pixels(in: sheet, x: 21..<80, y: 21..<46, labelled(colors[0]), tolerance: tolerance) > 0)
        #expect(pixels(in: sheet, x: 515..<574, y: 305..<330, labelled(colors[3]), tolerance: tolerance) > 0)
    }

    @Test("a sheet cell of an HDR video is its analysis picture, tone mapped as extract writes the frame")
    func drawsHighDynamicRangeVideoSheet() async throws {
        // Given
        // 300 cd/m² is above reference white, so it is white clipped and a light grey tone mapped.
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let video = media.file("pq.mov")
        let encoded = PerceptualQuantizer().encoded(displayLight: 300)
        try await ColorMovieWriter(size: Size(width: 160, height: 90), colorSpace: .rec2100PQ)
            .write(to: video, red: encoded, green: encoded, blue: encoded)
        let face = try labelFace()
        let sut = exporter()

        // When
        try sut.sheet(
            .video(path: video),
            range: FrameRange(),
            columns: 1,
            labelFace: face,
            to: output.file("sheet.png")
        )
        let files = try sut.extract(.video(path: video), range: FrameRange(), to: output.file("frames"))

        // Then
        let sheet = try picture(at: output.file("sheet.png"))
        let frame = try picture(at: try #require(files.first))
        let cell = sheet.pixel(x: 94, y: 59)
        let extracted = frame.pixel(x: 80, y: 45)
        #expect(extracted[0] < 0.99, "\(extracted)")
        #expect(zip(cell, extracted).allSatisfy { abs($0 - $1) <= 2.0 / 255 }, "\(cell) \(extracted)")
    }

    @Test("a sheet of a document draws its frames as still does, and never enlarges a small frame")
    func drawsDocumentSheet() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let document = try sequence(in: media)
        let face = try labelFace()
        let sut = exporter()

        // When
        try sut.sheet(
            .document(document),
            range: FrameRange(step: 0.5),
            columns: 6,
            labelFace: face,
            to: output.file("sheet.png")
        )

        // Then
        let sheet = try picture(at: output.file("sheet.png"))
        #expect(sheet.width == 14 + 160 + 14 + 160 + 14)
        #expect(sheet.isPixel(x: 94, y: 59, orange, tolerance: 1.0 / 255))
        #expect(sheet.isPixel(x: 268, y: 59, blue, tolerance: 1.0 / 255))
    }

    @Test("a sheet cell of a frame with motion blur is the frame as the renderer draws it, the mean of its samples")
    func drawsMotionBlurSheet() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let file = try image(in: media, named: "orange.png", color: orange)
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 },
              "storyline": [ { "kind": "media", "media": "\#(file)", "duration": 1, "motionBlur": true,
                               "keyframes": [ { "at": 0, "opacity": 1, "ease": "linear" }, { "at": 1, "opacity": 0 } ] } ] }
            """#)
        let face = try labelFace()
        let sut = exporter()

        // When
        try sut.sheet(
            .document(document),
            range: FrameRange(step: 0.5),
            columns: 6,
            labelFace: face,
            to: output.file("sheet.png")
        )

        // Then
        // The exposures run over [0, 0.05) and [0.5, 0.55), so the mean opacities are those at 0.025 and 0.525.
        let sheet = try picture(at: output.file("sheet.png"))
        #expect(sheet.isPixel(x: 94, y: 59, orange.map { $0 * 0.975 }, tolerance: 2.0 / 255))
        #expect(sheet.isPixel(x: 268, y: 59, orange.map { $0 * 0.475 }, tolerance: 2.0 / 255))
    }

    @Test("extract writes a video's frames over the range at full size, named by index, into a directory it makes")
    func extractsVideo() async throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let video = try await self.video(in: media)
        let directory = output.file("nested/frames")
        let sut = exporter()

        // When
        let files = try sut.extract(.video(path: video), range: FrameRange(from: 1), to: directory)

        // Then
        #expect(files == ["0000.png", "0001.png", "0002.png"].map { "\(directory)/\($0)" })
        let names = try FileManager.default.contentsOfDirectory(atPath: directory).sorted()
        #expect(names == ["0000.png", "0001.png", "0002.png"])
        for (index, file) in files.enumerated() {
            let frame = try picture(at: file)
            #expect(frame.width == 640 && frame.height == 360)
            #expect(frame.isPixel(x: 320, y: 180, colors[index + 1], tolerance: tolerance), "\(file)")
        }
    }

    @Test("extract writes a document's frames at sequence times before the range's end, without labels")
    func extractsDocument() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let document = try sequence(in: media)
        let sut = exporter()

        // When
        let range = FrameRange(from: 0.2, to: 0.8, step: 0.2)
        let files = try sut.extract(.document(document), range: range, to: output.path)

        // Then
        #expect(files.map { ($0 as NSString).lastPathComponent } == ["0000.png", "0001.png", "0002.png"])
        let frames = try files.map(picture(at:))
        #expect(frames.allSatisfy { $0.width == 160 && $0.height == 90 })
        #expect(frames.map { $0.isPixel(x: 80, y: 89, orange, tolerance: 1.0 / 255) } == [true, true, false])
        #expect(frames[2].isPixel(x: 80, y: 89, blue, tolerance: 1.0 / 255))
    }

    @Test("a time outside the sequence, an output that is not a PNG and a file that is not a video, a PDF included, stop")
    func refusesBadArguments() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let document = try sequence(in: media)
        let still = media.file("orange.png")
        let page = media.file("card.pdf")
        try PageWriter().write(width: 100, height: 100, content: "1 g 0 0 100 100 re f", to: page)
        let face = try labelFace()
        let sut = exporter()

        // When, Then
        #expect(throws: ExportError.timeOutside(option: "--at", time: 1, end: 1, kind: "sequence")) {
            try sut.still(document, at: [0.5, 1], labelFace: face, to: output.file("still.png"))
        }
        #expect(throws: ExportError.outputExtension(path: output.file("sheet.jpg"))) {
            try sut.sheet(
                .document(document),
                range: FrameRange(),
                columns: 6,
                labelFace: face,
                to: output.file("sheet.jpg")
            )
        }
        #expect(throws: ExportError.nonPositiveColumns(0)) {
            try sut.sheet(
                .document(document),
                range: FrameRange(),
                columns: 0,
                labelFace: face,
                to: output.file("sheet.png")
            )
        }
        #expect(throws: ExportError.notVideo(path: still, kind: .image)) {
            try sut.extract(.video(path: still), range: FrameRange(), to: output.file("frames"))
        }
        #expect(throws: ExportError.notVideo(path: page, kind: .page)) {
            try sut.extract(.video(path: page), range: FrameRange(), to: output.file("frames"))
        }
        #expect(throws: ExportError.missingMedia(path: media.file("none.mov"))) {
            try sut.extract(.video(path: media.file("none.mov")), range: FrameRange(), to: output.file("frames"))
        }
        #expect(try contents(of: output).isEmpty)
    }

    @Test("a document whose pinned file changed is refused before the directory is made")
    func refusesChangedFile() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let document = try sequence(in: media)
        _ = try image(in: media, named: "orange.png", color: [255, 129, 0])
        let sut = exporter()

        // When
        let error = #expect(throws: PinnedReferenceError.self) {
            try sut.extract(.document(document), range: FrameRange(), to: output.file("frames"))
        }

        // Then
        guard case let .changedFile(_, place) = error else {
            Issue.record("refused with \(String(describing: error))")
            return
        }
        #expect(place == "storyline[0]")
        #expect(try contents(of: output).isEmpty)
    }

    // MARK: - Private
    private func exporter() -> FrameExporter {
        let decoder = AVFoundationDecoder()

        return FrameExporter(
            decoder: decoder,
            renderer: QuartzRenderer(decoder: decoder),
            encoder: AVFoundationEncoder(),
            mediaFacts: decoder,
            shaper: CoreTextShaper()
        )
    }

    private func labelFace() throws -> FontFace {
        try #require(
            CoreTextShaper().face(named: "HelveticaNeue-Medium", in: "/System/Library/Fonts/HelveticaNeue.ttc")
        )
    }

    // An orange image for [0, 0.5) and a blue one for [0.5, 1), at 160 x 90 and 10 frames a second.
    private func sequence(
        in media: TemporaryDirectory,
        theme: String = "{}"
    ) throws -> ResolvedSequence {
        let first = try image(in: media, named: "orange.png", color: orange)
        let second = try image(in: media, named: "blue.png", color: blue)

        return try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 }, "theme": \#(theme),
              "storyline": [ { "kind": "media", "media": "\#(first)", "duration": 0.5 }, { "kind": "media", "media": "\#(second)", "duration": 0.5 } ] }
            """#)
    }

    // A 640 x 360 video whose frame i, shown from second i to i + 1, is `colors[i]`.
    private func video(in media: TemporaryDirectory) async throws -> String {
        let file = media.file("colors.mov")
        try await MovieWriter(size: Size(width: 640, height: 360), frameTimes: [0, 1, 2, 3], end: 4)
            .write(to: file) { canvas, index in
                canvas.fill(red: colors[index][0], green: colors[index][1], blue: colors[index][2])
            }

        return file
    }

    private func image(
        in directory: TemporaryDirectory,
        named name: String,
        color: [Double]
    ) throws -> String {
        let file = directory.file(name)
        try ImageWriter(size: Size(width: 160, height: 90)).write(to: file) { canvas in
            canvas.fill(red: color[0], green: color[1], blue: color[2])
        }

        return file
    }

    private func picture(at path: String) throws -> Bitmap {
        try AVFoundationDecoder().picture(of: MediaFile(path: path), atFrame: 0).bitmap
    }

    // `color` under a label's background, black at an alpha of 0xB3.
    private func labelled(_ color: [Double]) -> [Double] {
        color.map { $0 * (1 - 0xB3 / 255.0) }
    }

    // The pixels in the area that show `color`.
    private func pixels(
        in bitmap: Bitmap,
        x columns: Range<Int>,
        y rows: Range<Int>,
        _ color: [Double],
        tolerance: Double
    ) -> Int {
        rows.flatMap { row in columns.map { column in (column, row) } }
            .filter { bitmap.isPixel(x: $0.0, y: $0.1, color, tolerance: tolerance) }
            .count
    }

    private func contents(of directory: TemporaryDirectory) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }
}
