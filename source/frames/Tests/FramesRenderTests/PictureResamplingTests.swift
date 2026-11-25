//
//  PictureResamplingTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/25/26.
//

import CoreGraphics
import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// Each renderer against the definition of resampling on the named set of FRAMES-24: a detailed still scaled, moved by
// part of a pixel and turned, every pixel within 2^-9 x max(1, |v|) of the definition and 2^-12 of it on average.
@Suite("Picture Resampling Tests", .serialized, .ownThread)
struct PictureResamplingTests {
    // MARK: - Property
    private static let origin = CGPoint(x: 5.375, y: 3.625)
    private static let sourceSize = CGSize(width: 64, height: 48)
    private static let outputSize = Size(width: 256, height: 256)

    private let directory: TemporaryDirectory

    // MARK: - Initializer
    init() throws {
        directory = try TemporaryDirectory()
    }

    // MARK: - Test
    @Test(
        "each renderer resamples the still within the bounds of the definition at every scale and turn of the set",
        arguments: ["quartz", "metal"]
    )
    func resamplesByDefinition(renderer: String) throws {
        // Given
        let decoder = AVFoundationDecoder()
        let sut: any Renderer = renderer == "quartz" ? QuartzRenderer(decoder: decoder) : MetalRenderer(decoder: decoder)
        let frame = try still()
        let source = try decoder.picture(of: MediaFile(picture: frame.media), atFrame: 0).bitmap
        let placements = [0.25, 0.625, 1, 1.375, 3].map { ($0, 0.0) } + [(1, 17.0), (0.625, 17.0)]

        for (scale, degrees) in placements {
            let (item, map) = placed(frame, scale: scale, degrees: degrees)
            let reference = ResamplingReference(source: source, map: map)

            // When
            let bitmap = try sut.bitmap(
                of: DisplayList(size: Self.outputSize, background: Color(written: "#00000000"), seed: 0, items: [item])
            )

            // Then
            var largest = 0.0
            var sum = 0.0
            var count = 0
            for y in 0..<Int(Self.outputSize.height) {
                for x in 0..<Int(Self.outputSize.width) {
                    let expected = reference.pixel(x: x, y: y)
                    let pixel = bitmap.pixel(x: x, y: y)
                    let reached = reference.coverage(x: x, y: y) > 0
                    for component in 0..<4 {
                        let difference = abs(pixel[component] - expected[component])
                        largest = max(largest, difference / max(1, abs(expected[component])))
                        if reached {
                            sum += difference
                            count += 1
                        }
                    }
                }
            }
            let mean = sum / Double(count)
            let name = "\(renderer) at scale \(scale) turned by \(degrees)"
            print("resampling \(name): largest \(largest), mean \(mean)")
            #expect(largest <= 0x1p-9, "\(name): largest \(largest)")
            #expect(mean <= 0x1p-12, "\(name): mean \(mean)")
        }
    }

    @Test(
        "each renderer covers a picture's edge once, so it lies at its geometric position within 1/64 px, scaled or not",
        arguments: ["quartz", "metal"]
    )
    func coversEdgeOnce(renderer: String) throws {
        // Given
        let decoder = AVFoundationDecoder()
        let sut: any Renderer = renderer == "quartz" ? QuartzRenderer(decoder: decoder) : MetalRenderer(decoder: decoder)
        let white = try white()
        let items = [
            Rectangle(x: 38.3125, y: 18.8125, width: 44, height: 44),
            Rectangle(x: 110.375, y: 40.625, width: 32, height: 32)
        ]
        .map { DisplayItem(content: .picture(PictureItem(source: .media(white), rectangle: nil, destination: $0))) }
        let probes = [
            (EdgeProbe(name: "scaled left", isVertical: true, inside: 50, outside: 33, along: 30..<50), 38.3125),
            (EdgeProbe(name: "scaled right", isVertical: true, inside: 70, outside: 88, along: 30..<50), 82.3125),
            (EdgeProbe(name: "scaled top", isVertical: false, inside: 30, outside: 13, along: 50..<70), 18.8125),
            (EdgeProbe(name: "scaled bottom", isVertical: false, inside: 50, outside: 68, along: 50..<70), 62.8125),
            (EdgeProbe(name: "unscaled left", isVertical: true, inside: 120, outside: 105, along: 50..<70), 110.375),
            (EdgeProbe(name: "unscaled top", isVertical: false, inside: 55, outside: 35, along: 120..<135), 40.625)
        ]

        // When
        let bitmap = try sut.bitmap(
            of: DisplayList(size: Size(width: 160, height: 90), background: Color(written: "#00000000"), seed: 0, items: items)
        )

        // Then
        for (probe, expected) in probes {
            let position = probe.position(in: bitmap)
            print("edge \(renderer) \(probe.name): \(position), geometric \(expected)")
            #expect(abs(position - expected) <= 0x1p-6, "\(renderer) \(probe.name): \(position) is not \(expected)")
        }
    }

    // MARK: - Private
    // The still's picture item with its destination's top left at the set's origin, `scale` output pixels a source
    // pixel, turned by `degrees` about the destination's centre, and the map from the source's pixels to the output's.
    private func placed(
        _ frame: MediaFrame,
        scale: Double,
        degrees: Double
    ) -> (DisplayItem, CGAffineTransform) {
        let destination = CGRect(
            x: Self.origin.x,
            y: Self.origin.y,
            width: Self.sourceSize.width * scale,
            height: Self.sourceSize.height * scale
        )
        let angle = degrees * Double.pi / 180
        let turn = CGAffineTransform(translationX: -destination.midX, y: -destination.midY)
            .concatenating(CGAffineTransform(rotationAngle: angle))
            .concatenating(CGAffineTransform(translationX: destination.midX, y: destination.midY))
        let picture = PictureItem(
            source: .media(frame),
            rectangle: nil,
            destination: Rectangle(
                x: destination.minX,
                y: destination.minY,
                width: destination.width,
                height: destination.height
            )
        )
        let transform = AffineTransform(a: turn.a, b: turn.b, c: turn.c, d: turn.d, tx: turn.tx, ty: turn.ty)
        let map = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: destination.minX, y: destination.minY))
            .concatenating(turn)

        return (DisplayItem(transform: transform, content: .picture(picture)), map)
    }

    // A 32 x 32 opaque white still.
    private func white() throws -> MediaFrame {
        let path = directory.file("white.png")
        try ImageWriter(size: Size(width: 32, height: 32)).write(to: path) { canvas in
            canvas.fill(red: 255, green: 255, blue: 255)
        }

        return MediaFrame(media: PinnedMedia(source: .file(PinnedFile(path: path, sha256: ""), frameTimes: nil)), index: 0)
    }

    // The set's still: pixel (i, j) holds (((3i + 5j) mod 17) / 16, ((7i + 2j) mod 13) / 12, (i + j) mod 2) at alpha 1,
    // written at sixteen bits.
    private func still() throws -> MediaFrame {
        let path = directory.file("detail.png")
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        try ImageWriter(size: Size(width: Self.sourceSize.width, height: Self.sourceSize.height), bitsPerComponent: 16)
            .write(to: path) { canvas in
                for row in 0..<Int(Self.sourceSize.height) {
                    for column in 0..<Int(Self.sourceSize.width) {
                        let components: [CGFloat] = [
                            CGFloat((3 * column + 5 * row) % 17) / 16,
                            CGFloat((7 * column + 2 * row) % 13) / 12,
                            CGFloat((column + row) % 2),
                            1
                        ]
                        canvas.context.setFillColor(CGColor(colorSpace: colorSpace, components: components)!)
                        canvas.context.fill(CGRect(x: column, y: row, width: 1, height: 1))
                    }
                }
            }

        return MediaFrame(media: PinnedMedia(source: .file(PinnedFile(path: path, sha256: ""), frameTimes: nil)), index: 0)
    }
}
