//
//  TranscoderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames

@Suite("Transcoder Tests")
struct TranscoderTests {
    // MARK: - Property
    private static let sourceByteCount = 100
    private static let existing = Data("existing".utf8)

    private let silence = SoundBuffer(sampleRate: 48_000, channels: 2, samples: [])

    // MARK: - Initializer
    // MARK: - Test
    @Test("an image goes to the image target its extension names, at the quality asked", arguments: [
        ("jpg", TranscodeFormat.jpeg),
        ("heic", TranscodeFormat.heic),
        ("png", TranscodeFormat.png),
        ("JPG", TranscodeFormat.jpeg)
    ])
    func writesImage(
        outputExtension: String,
        format: TranscodeFormat
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.png")
        let output = directory.file("out.\(outputExtension)")
        let sut = transcoder(log: log, facts: [input: image(width: 40, height: 30)])

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output, quality: .low))

        // Then
        let size = Size(width: 40, height: 30)
        let target: ImageTarget = switch format {
        case .jpeg:
            .jpeg(path: output, size: size, quality: .low)

        case .heic:
            .heic(path: output, size: size, quality: .low)

        default:
            .png(path: output, size: size)
        }
        #expect(log.calls == [
            .checkMedia(path: input),
            .readPicture(path: input, frame: 0, reading: .working(colorSpace: nil, targetPeak: 203)),
            .checkImageTarget(target),
            .writeImageTarget(target, frame: 0)
        ])
        #expect(result.format == format)
    }

    @Test("a page is drawn whole at --scale, by default at 4 per point or at the held scale, to a 16-bit PNG", arguments: [
        (nil, Size(width: 100, height: 50.4), 4.0, PageRegion(x: 0, y: 0, width: 400, height: 202)),
        (1.5, Size(width: 100, height: 50.4), 1.5, PageRegion(x: 0, y: 0, width: 150, height: 76)),
        (nil, Size(width: 8_192, height: 100), 2.0, PageRegion(x: 0, y: 0, width: 16_384, height: 200))
    ])
    func writesPage(
        scale: Double?,
        pageSize: Size,
        drawnScale: Double,
        region: PageRegion
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "deck.pdf")
        let output = directory.file("page.png")
        let sut = pageTranscoder(log: log, input: input, pageCount: 2, pageSize: pageSize)

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, page: 2, output: output, scale: scale))

        // Then
        let target = ImageTarget.png(
            path: output,
            size: Size(width: Double(region.width), height: Double(region.height)),
            depth: .sixteen
        )
        let reading = PictureReading.working(colorSpace: nil, targetPeak: 203)
        #expect(log.calls == [
            .checkMedia(path: input),
            .checkMedia(path: input),
            .readPage(path: input, page: 2, region: region, scale: drawnScale, reading: reading),
            .checkImageTarget(target),
            .writeImageTarget(target, frame: 0)
        ])
        #expect(result.format == .png)
    }

    @Test("a page its decoder refuses for its fonts is read by the platform into the output's space")
    func readsPageByPlatform() throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "logo.pdf")
        let output = directory.file("logo.jpg")
        let sut = pageTranscoder(log: log, input: input, pageCount: 1, colorReading: .platform)

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output, colorSpace: .displayP3))

        // Then
        let reads = log.calls.filter { if case .readPage = $0 { true } else { false } }
        #expect(reads == [
            .readPage(
                path: input,
                page: 1,
                region: PageRegion(x: 0, y: 0, width: 4, height: 4),
                scale: 4,
                reading: .platform(colorSpace: .displayP3)
            )
        ])
    }

    @Test("--max on a page, --scale on an image, and a written --scale the decoder cannot hold stop, naming them")
    func refusesPageOptions() throws {
        // Given
        let directory = try TemporaryDirectory()
        let page = try source(in: directory, name: "logo.pdf")
        let image = try source(in: directory, name: "in.png")
        let output = try existingOutput(in: directory, name: "out.png")
        let log = RoleCallLog()
        let sut = Transcoder(
            decoder: RecordingDecoder(log: log, pageSize: Size(width: 100, height: 50)),
            facts: MediaFactTable(
                files: [image: self.image(width: 40, height: 30)],
                pages: [page: [Size(width: 100, height: 50)]]
            ),
            encoder: RecordingEncoder(log: log)
        )

        // When
        let capped = #expect(throws: TranscodeError.self) {
            try sut.transcode(TranscodeRequest(input: page, output: output, maximumSide: 64))
        }
        let scaled = #expect(throws: TranscodeError.self) {
            try sut.transcode(TranscodeRequest(input: image, output: output, scale: 2))
        }
        let large = #expect(throws: TranscodeError.self) {
            try sut.transcode(TranscodeRequest(input: page, output: output, scale: 200))
        }
        let huge = #expect(throws: TranscodeError.self) {
            try sut.transcode(TranscodeRequest(input: page, output: output, scale: 1e300))
        }

        // Then
        #expect(capped == .maximumSideOfPage(input: page))
        #expect(scaled == .scaleOfRaster(input: image))
        #expect(large == .pageTooLarge(path: output, scale: 200, size: Size(width: 20_000, height: 10_000), largest: 16_384))
        #expect(huge == .pageTooLarge(path: output, scale: 1e300, size: Size(width: 100 * 1e300, height: 50 * 1e300), largest: 16_384))
        #expect(large?.description == """
            \(JSONValue.string(output).written): --scale 200 draws the page at 20000x10000, and the decoder holds at \
            most 16384 pixels on a side
            """)
        #expect(!log.calls.contains { if case .readPage = $0 { true } else { false } })
        #expect(try Data(contentsOf: URL(fileURLWithPath: output)) == Self.existing)
    }

    @Test("a PDF of more than one page with no --page stops, naming its page count")
    func refusesUnnamedPage() throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "deck.pdf")
        let sut = pageTranscoder(log: log, input: input, pageCount: 3)

        // When
        let thrown = #expect(throws: AnalysisError.self) {
            try sut.transcode(TranscodeRequest(input: input, output: directory.file("page.png")))
        }

        // Then
        #expect(thrown == .unnamedPage(file: input, pageCount: 3))
        #expect(log.calls.isEmpty)
    }

    @Test("a sound goes to AAC in an .m4a, read whole through the decoder")
    func writesSound() throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.wav")
        let output = directory.file("out.m4a")
        let sut = transcoder(log: log, facts: [input: ProbedMedia(kind: .audio, duration: 2.5, sound: stereo)])

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output, quality: .high))

        // Then
        let target = SoundTarget(path: output, quality: .high, layout: silence.layout, sampleRate: silence.sampleRate)
        #expect(log.calls == [
            .checkMedia(path: input),
            .readSound(path: input, from: 0, to: 2.5),
            .checkSoundTarget(target),
            .writeSound(target, sound: silence)
        ])
        #expect(result.format == .aac)
    }

    @Test("a video to an .m4a writes its sound alone")
    func writesSoundOfVideo() throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.mov")
        let output = directory.file("out.m4a")
        let sut = transcoder(log: log, facts: [input: video(hasSound: true)])

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        let target = SoundTarget(path: output, quality: .medium, layout: silence.layout, sampleRate: silence.sampleRate)
        #expect(log.calls == [
            .checkMedia(path: input),
            .readSound(path: input, from: 0, to: 0.5),
            .checkSoundTarget(target),
            .writeSound(target, sound: silence)
        ])
        #expect(result.format == .aac)
    }

    @Test(
        "a video goes frame by frame at its frame rate, each the frame shown then, with its sound, in H.264 by default",
        arguments: [nil, VideoCodec.hevc]
    )
    func writesVideo(codec: VideoCodec?) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.mov")
        let output = directory.file("out.mp4")
        let sut = transcoder(log: log, facts: [input: video(hasSound: true)])

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output, codec: codec))

        // Then
        let written = codec ?? .h264
        let target = EncodeTarget.compressed(
            path: output,
            codec: written,
            quality: .medium,
            size: Size(width: 40, height: 30)
        )
        #expect(log.calls == [
            .checkMedia(path: input),
            .readSound(path: input, from: 0, to: 0.5),
            .checkTarget(target),
            .checkSoundTarget(
                SoundTarget(path: output, quality: .medium, layout: silence.layout, sampleRate: silence.sampleRate)
            ),
            .videoWriter(target, size: Size(width: 40, height: 30), fps: 10, sound: silence)
        ] + [0, 0, 0, 1, 1].flatMap { frame -> [RoleCall] in
            [
                .readPicture(path: input, frame: frame, reading: .working(colorSpace: nil, targetPeak: 203)),
                .append(path: output, frame: frame)
            ]
        } + [
            .finish(path: output)
        ])
        #expect(result.format == .video(codec: written, hasSound: true))
    }

    @Test(
        "an image is written in the source's colour space, srgb outside the table, or the one --color-space names",
        arguments: [
            (ColorReading.formulas(.rec2100PQ), nil as ColorSpace?, ColorSpace.rec2100PQ, BitDepth.sixteen),
            (.formulas(.displayP3), nil, .displayP3, .eight),
            (.formulas(nil), nil, .srgb, .eight),
            (.formulas(.rec2100HLG), .srgb, .srgb, .eight),
            (.formulas(.srgb), .rec2100HLG, .rec2100HLG, .sixteen)
        ]
    )
    func writesImageInColorSpace(
        colorReading: ColorReading,
        colorSpace: ColorSpace?,
        written: ColorSpace,
        depth: BitDepth
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.png")
        let output = directory.file("out.png")
        let sut = transcoder(log: log, facts: [input: image(width: 40, height: 30)], colorReading: colorReading)

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output, colorSpace: colorSpace))

        // Then
        let conversion = ColorConversion(space: written)
        let target = ImageTarget.png(path: output, size: Size(width: 40, height: 30), depth: depth, output: conversion)
        #expect(log.calls == [
            .checkMedia(path: input),
            .readPicture(path: input, frame: 0, reading: .working(colorSpace: nil, targetPeak: conversion.peak)),
            .checkImageTarget(target),
            .writeImageTarget(target, frame: 0)
        ])
    }

    @Test("an SDR PNG takes the bit depth the source probes at, not the depth of the picture read", arguments: [8, 16])
    func writesProbedDepth(bitDepth: Int) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.png")
        let output = directory.file("out.png")
        let probed = ProbedColorSpace(
            reading: .formulas(.srgb),
            primaries: nil,
            transfer: nil,
            matrix: nil,
            bitDepth: bitDepth,
            isHighDynamicRange: false
        )
        let facts = [input: ProbedMedia(kind: .image, size: Size(width: 40, height: 30), colorSpace: probed)]
        let sut = transcoder(log: log, facts: facts)

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        let target = ImageTarget.png(
            path: output,
            size: Size(width: 40, height: 30),
            depth: BitDepth(holding: bitDepth),
            output: ColorConversion(space: .srgb)
        )
        #expect(log.calls.contains(.writeImageTarget(target, frame: 0)))
    }

    @Test("a source no formula reads is read once by the platform's colour management into the output's space")
    func readsByPlatform() throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.mov")
        let output = directory.file("out.mov")
        let sut = transcoder(log: log, facts: [input: video(hasSound: false)], colorReading: .platform)

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output, colorSpace: .rec2100HLG))

        // Then
        let reads = log.calls.filter { if case .readPicture = $0 { true } else { false } }
        #expect(reads == [0, 0, 0, 1, 1].map {
            .readPicture(path: input, frame: $0, reading: .platform(colorSpace: .rec2100HLG))
        })
    }

    @Test(
        "a video in an HDR colour space is HEVC by default, and in an SDR one H.264",
        arguments: [(ColorSpace.rec2100PQ, VideoCodec.hevc), (.rec2020, .h264)]
    )
    func choosesCodecByColorSpace(
        space: ColorSpace,
        codec: VideoCodec
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.mov")
        let output = directory.file("out.mp4")
        let sut = transcoder(log: log, facts: [input: video(hasSound: false)], colorReading: .formulas(space))

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        let target = EncodeTarget.compressed(
            path: output,
            codec: codec,
            quality: .medium,
            size: Size(width: 40, height: 30),
            output: ColorConversion(space: space)
        )
        #expect(log.calls.contains(.checkTarget(target)))
        #expect(result.format == .video(codec: codec, hasSound: false))
    }

    @Test("--codec h264 and a .jpg output in an HDR colour space stop, naming what carries HDR", arguments: [
        ("in.mov", "out.mp4", VideoCodec.h264 as VideoCodec?, nil as ColorSpace?),
        ("in.mov", "out.mp4", .h264, .rec2100HLG),
        ("in.png", "out.jpg", nil, nil),
        ("in.png", "out.jpg", nil, .rec2100PQ)
    ])
    func stopsOnHighDynamicRange(
        inputName: String,
        outputName: String,
        codec: VideoCodec?,
        colorSpace: ColorSpace?
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try source(in: directory, name: inputName)
        let output = try existingOutput(in: directory, name: outputName)
        let isVideo = inputName == "in.mov"
        let media = isVideo ? video(hasSound: true) : image(width: 40, height: 30)
        let written = colorSpace ?? .rec2100PQ

        // When
        let request = TranscodeRequest(input: input, output: output, codec: codec, colorSpace: colorSpace)

        // Then
        try expectStop(
            request,
            facts: [input: media],
            colorReading: .formulas(.rec2100PQ),
            error: isVideo
                ? .highDynamicRangeCodec(path: output, colorSpace: written)
                : .highDynamicRangeJPEG(path: output, colorSpace: written)
        )
    }

    @Test("--color-space for an output of sound only stops", arguments: [("in.wav", "out.m4a"), ("in.mov", "out.m4a")])
    func stopsOnColorSpaceWithoutPicture(
        inputName: String,
        outputName: String
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try source(in: directory, name: inputName)
        let output = try existingOutput(in: directory, name: outputName)
        let media = inputName == "in.wav" ? ProbedMedia(kind: .audio, duration: 1, sound: stereo) : video(hasSound: true)

        // When
        let request = TranscodeRequest(input: input, output: output, colorSpace: .displayP3)

        // Then
        try expectStop(request, facts: [input: media], error: .colorSpaceWithoutPicture(path: output))
    }

    @Test("a video without sound is written without sound", arguments: ["mp4", "mov", "m4v"])
    func writesSilentVideo(outputExtension: String) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.mov")
        let output = directory.file("out.\(outputExtension)")
        let sut = transcoder(log: log, facts: [input: video(hasSound: false)])

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        #expect(!log.calls.contains { if case .readSound = $0 { true } else { false } })
        #expect(log.calls.contains { if case .videoWriter(_, _, _, .none) = $0 { true } else { false } })
        #expect(result.format == .video(codec: .h264, hasSound: false))
    }

    @Test("--max caps an image's longer side, never enlarges it, and rounds each side to whole pixels", arguments: [
        (Size(width: 1920, height: 1080), 960, Size(width: 960, height: 540)),
        (Size(width: 1080, height: 1920), 100, Size(width: 56, height: 100)),
        (Size(width: 1000, height: 750), 2000, Size(width: 1000, height: 750)),
        (Size(width: 101, height: 75), nil, Size(width: 101, height: 75))
    ] as [(Size, Int?, Size)])
    func capsImageSide(
        source size: Size,
        maximumSide: Int?,
        expected: Size
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.png")
        let output = directory.file("out.png")
        let sut = transcoder(log: log, facts: [input: ProbedMedia(kind: .image, size: size)])

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output, maximumSide: maximumSide))

        // Then
        #expect(log.calls.contains(.checkImageTarget(.png(path: output, size: expected))))
    }

    @Test("--max caps a video's longer side, never enlarges it, and takes each exact side down to an even one", arguments: [
        (Size(width: 1920, height: 1080), 1000, Size(width: 1000, height: 562)),
        (Size(width: 1920, height: 1080), 999, Size(width: 998, height: 560)),
        (Size(width: 1000, height: 508), 200, Size(width: 200, height: 100)),
        (Size(width: 1080, height: 1920), 640, Size(width: 360, height: 640)),
        (Size(width: 640, height: 360), 2000, Size(width: 640, height: 360)),
        (Size(width: 101, height: 75), nil, Size(width: 100, height: 74))
    ] as [(Size, Int?, Size)])
    func capsVideoSide(
        source size: Size,
        maximumSide: Int?,
        expected: Size
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.mov")
        let output = directory.file("out.mp4")
        let media = ProbedMedia(kind: .video, duration: 0.1, fps: 10, frames: [0], size: size)
        let sut = transcoder(log: log, facts: [input: media])

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output, maximumSide: maximumSide))

        // Then
        let target = EncodeTarget.compressed(path: output, codec: .h264, quality: .medium, size: expected)
        #expect(log.calls.contains(.checkTarget(target)))
        #expect(log.calls.contains(.videoWriter(target, size: size, fps: 10, sound: nil)))
    }

    @Test("the output as the input stops, by its path, a symbolic link or a hard link", arguments: [
        "path",
        "symbolic link",
        "hard link"
    ])
    func stopsOnSameFile(link: String) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.png")
        let output = link == "path" ? input : directory.file("link.png")
        if link == "symbolic link" {
            try FileManager.default.createSymbolicLink(atPath: output, withDestinationPath: input)
        } else if link == "hard link" {
            try FileManager.default.linkItem(atPath: input, toPath: output)
        }
        let sut = transcoder(log: log, facts: [input: image(width: 40, height: 30)])

        // When
        let thrown = #expect(throws: TranscodeError.self) {
            try sut.transcode(TranscodeRequest(input: input, output: output))
        }

        // Then
        #expect(thrown == .sameFile(path: output))
        #expect(log.calls.isEmpty)
        #expect(try Data(contentsOf: URL(fileURLWithPath: input)).count == Self.sourceByteCount)
    }

    @Test("an output extension that does not fit the input stops and leaves an existing output", arguments: [
        (MediaKind.image, "mp4", ["jpg", "heic", "png"]),
        (MediaKind.image, "jpeg", ["jpg", "heic", "png"]),
        (MediaKind.audio, "jpg", ["m4a"]),
        (MediaKind.audio, "mp4", ["m4a"]),
        (MediaKind.video, "png", ["mp4", "mov", "m4v", "m4a"]),
        (MediaKind.video, "wav", ["mp4", "mov", "m4v", "m4a"])
    ])
    func stopsOnExtension(
        kind: MediaKind,
        outputExtension: String,
        allowed: [String]
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try source(in: directory, name: "in")
        let output = try existingOutput(in: directory, name: "out.\(outputExtension)")
        let media = switch kind {
        case .image:
            image(width: 40, height: 30)

        case .audio:
            ProbedMedia(kind: .audio, duration: 1, sound: stereo)

        default:
            video(hasSound: true)
        }

        // When
        let request = TranscodeRequest(input: input, output: output)

        // Then
        try expectStop(
            request,
            facts: [input: media],
            error: .outputExtension(path: output, input: input, kind: kind, allowed: allowed)
        )
    }

    @Test("--codec for an output that is not a video stops", arguments: [
        ("in.png", "out.jpg"),
        ("in.wav", "out.m4a"),
        ("in.mov", "out.m4a")
    ])
    func stopsOnCodecWithoutVideo(
        inputName: String,
        outputName: String
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try source(in: directory, name: inputName)
        let output = try existingOutput(in: directory, name: outputName)
        let media = switch inputName {
        case "in.png":
            image(width: 40, height: 30)

        case "in.wav":
            ProbedMedia(kind: .audio, duration: 1, sound: stereo)

        default:
            video(hasSound: true)
        }

        // When
        let request = TranscodeRequest(input: input, output: output, codec: .hevc)

        // Then
        try expectStop(request, facts: [input: media], error: .codecWithoutVideo(path: output))
    }

    @Test("a video without sound to an .m4a stops")
    func stopsOnSilentVideoToSound() throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try source(in: directory, name: "in.mov")
        let output = try existingOutput(in: directory, name: "out.m4a")

        // When
        let request = TranscodeRequest(input: input, output: output)

        // Then
        try expectStop(request, facts: [input: video(hasSound: false)], error: .noSound(path: output, input: input))
    }

    @Test("a video without a frame rate stops", arguments: [nil, 0.0])
    func stopsOnNoFrameRate(fps: Double?) throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try source(in: directory, name: "in.mov")
        let output = try existingOutput(in: directory, name: "out.mp4")
        let media = ProbedMedia(kind: .video, duration: 1, fps: fps, frames: [0], size: Size(width: 40, height: 30))

        // When
        let request = TranscodeRequest(input: input, output: output)

        // Then
        try expectStop(request, facts: [input: media], error: .noFrameRate(path: input))
    }

    @Test("--max below one pixel stops", arguments: [0, -4])
    func stopsOnMaximumSide(maximumSide: Int) throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try source(in: directory, name: "in.png")
        let output = try existingOutput(in: directory, name: "out.png")

        // When
        let request = TranscodeRequest(input: input, output: output, maximumSide: maximumSide)

        // Then
        try expectStop(request, facts: [input: image(width: 40, height: 30)], error: .maximumSide(maximumSide))
    }

    @Test("a video side that rounds below 2 pixels stops, naming the size it would give and the cap that shrank it", arguments: [
        (Size(width: 1920, height: 1080), 1, Size(width: 0, height: 0)),
        (Size(width: 1920, height: 1080), 2, Size(width: 2, height: 0)),
        (Size(width: 400, height: 2), 100, Size(width: 100, height: 0)),
        (Size(width: 1920, height: 1080), 3, Size(width: 2, height: 0)),
        (Size(width: 1, height: 400), nil, Size(width: 0, height: 400))
    ])
    func stopsOnUndersizedVideo(
        source size: Size,
        maximumSide: Int?,
        fitted: Size
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try source(in: directory, name: "in.mov")
        let output = try existingOutput(in: directory, name: "out.mp4")
        let media = ProbedMedia(kind: .video, duration: 0.1, fps: 10, frames: [0], size: size)

        // When
        let request = TranscodeRequest(input: input, output: output, maximumSide: maximumSide)

        // Then
        try expectStop(
            request,
            facts: [input: media],
            error: .undersizedVideo(path: output, maximumSide: maximumSide, size: fitted)
        )
    }

    @Test("a cap larger than a video under 2 pixels wide is not named, since it shrank nothing")
    func stopsOnUndersizedSourceUnderLargerCap() throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try source(in: directory, name: "in.mov")
        let output = try existingOutput(in: directory, name: "out.mp4")
        let media = ProbedMedia(kind: .video, duration: 0.1, fps: 10, frames: [0], size: Size(width: 1, height: 400))

        // When
        let request = TranscodeRequest(input: input, output: output, maximumSide: 1000)

        // Then
        try expectStop(
            request,
            facts: [input: media],
            error: .undersizedVideo(path: output, maximumSide: nil, size: Size(width: 0, height: 400))
        )
    }

    @Test("an input that is not there stops")
    func stopsOnMissingInput() throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = directory.file("missing.png")
        let output = try existingOutput(in: directory, name: "out.png")

        // When
        let request = TranscodeRequest(input: input, output: output)

        // Then
        try expectStop(request, facts: [:], error: .missingInput(path: input))
    }

    @Test("an output that is a directory stops, and the directory stays")
    func stopsOnDirectory() throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.png")
        let output = directory.file("folder.png")
        try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: false)
        let sut = transcoder(log: log, facts: [input: image(width: 40, height: 30)])

        // When
        let thrown = #expect(throws: TranscodeError.self) {
            try sut.transcode(TranscodeRequest(input: input, output: output))
        }

        // Then
        #expect(thrown == .outputDirectory(path: output))
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: output, isDirectory: &isDirectory) && isDirectory.boolValue)
    }

    @Test("a decoder or an encoder that refuses stops with an existing output left as it was", arguments: [
        RoleRefusal.decoder,
        RoleRefusal.encoder
    ])
    func keepsOutputOnRefusal(refusal: RoleRefusal) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.mov")
        let output = try existingOutput(in: directory, name: "out.mp4")
        let sut = transcoder(log: log, facts: [input: video(hasSound: true)], refusal: refusal)

        // When
        #expect(throws: refusal) {
            try sut.transcode(TranscodeRequest(input: input, output: output))
        }

        // Then
        #expect(try Data(contentsOf: URL(fileURLWithPath: output)) == Self.existing)
        #expect(!log.calls.contains { if case .videoWriter = $0 { true } else { false } })
    }

    @Test("an encoder that refuses a sound's layout stops before an existing output is removed", arguments: [
        ("in.wav", "out.m4a"),
        ("in.mov", "out.m4a")
    ])
    func keepsOutputOnRefusedSound(
        inputName: String,
        outputName: String
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: inputName)
        let output = try existingOutput(in: directory, name: outputName)
        let media = inputName == "in.wav"
            ? ProbedMedia(kind: .audio, duration: 1, sound: stereo)
            : video(hasSound: true)
        let sut = transcoder(log: log, facts: [input: media], refusal: .encoder)

        // When
        #expect(throws: RoleRefusal.encoder) {
            try sut.transcode(TranscodeRequest(input: input, output: output))
        }

        // Then
        #expect(try Data(contentsOf: URL(fileURLWithPath: output)) == Self.existing)
        let target = SoundTarget(path: output, quality: .medium, layout: silence.layout, sampleRate: silence.sampleRate)
        #expect(log.calls.last == .checkSoundTarget(target))
    }

    @Test("an existing output is removed once every check has passed, before the encoder writes", arguments: [
        ("in.png", "out.jpg"),
        ("in.wav", "out.m4a"),
        ("in.mov", "out.mp4")
    ])
    func removesOutputAfterChecks(
        inputName: String,
        outputName: String
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: inputName)
        let output = try existingOutput(in: directory, name: outputName)
        let media = switch inputName {
        case "in.png":
            image(width: 40, height: 30)

        case "in.wav":
            ProbedMedia(kind: .audio, duration: 1, sound: stereo)

        default:
            video(hasSound: true)
        }
        let sut = transcoder(log: log, facts: [input: media])

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        #expect(!log.calls.contains(.replace(path: output)))
        #expect(try Data(contentsOf: URL(fileURLWithPath: output)).count == RecordingEncoder.writtenByteCount)
    }

    @Test("the result gives the output's bytes over the source's, and whether it is smaller", arguments: [
        (100, 0.1, true),
        (10, 1.0, false),
        (4, 2.5, false)
    ])
    func reportsSize(
        sourceByteCount: Int,
        ratio: Double,
        isSmaller: Bool
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let input = try source(in: directory, name: "in.png", byteCount: sourceByteCount)
        let output = directory.file("out.jpg")
        let sut = transcoder(log: log, facts: [input: image(width: 40, height: 30)])

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        #expect(result == TranscodeResult(
            path: output,
            byteCount: RecordingEncoder.writtenByteCount,
            sourceByteCount: sourceByteCount,
            format: .jpeg
        ))
        #expect(result.ratio == ratio)
        #expect(result.isSmaller == isSmaller)
    }

    // MARK: - Private
    private func transcoder(
        log: RoleCallLog,
        facts files: [String: ProbedMedia],
        refusal: RoleRefusal? = nil,
        colorReading: ColorReading = .formulas(.srgb)
    ) -> Transcoder {
        Transcoder(
            decoder: RecordingDecoder(log: log, refuses: refusal == .decoder, colorReading: colorReading),
            facts: MediaFactTable(files: files),
            encoder: RecordingEncoder(log: log, refuses: refusal == .encoder)
        )
    }

    // A transcoder whose `input` is a PDF of `pageCount` pages, each of `pageSize` points.
    private func pageTranscoder(
        log: RoleCallLog,
        input: String,
        pageCount: Int,
        pageSize: Size = Size(width: 1, height: 1),
        colorReading: ColorReading = .formulas(.srgb)
    ) -> Transcoder {
        Transcoder(
            decoder: RecordingDecoder(log: log, colorReading: colorReading, pageSize: pageSize),
            facts: MediaFactTable(files: [:], pages: [input: Array(repeating: pageSize, count: pageCount)]),
            encoder: RecordingEncoder(log: log)
        )
    }

    private func image(
        width: Double,
        height: Double
    ) -> ProbedMedia {
        ProbedMedia(kind: .image, size: Size(width: width, height: height))
    }

    private var stereo: ProbedSound {
        ProbedSound(channels: 2, sampleRate: 48_000)
    }

    // Half a second at 10 frames a second whose frames come at 0 and 0.25, as a variable rate recording's do.
    private func video(hasSound: Bool) -> ProbedMedia {
        ProbedMedia(
            kind: .video,
            duration: 0.5,
            fps: 10,
            frames: [0, 0.25],
            size: Size(width: 40, height: 30),
            sound: hasSound ? stereo : nil
        )
    }

    private func source(
        in directory: TemporaryDirectory,
        name: String,
        byteCount: Int = Self.sourceByteCount
    ) throws -> String {
        let path = directory.file(name)
        try Data(count: byteCount).write(to: URL(fileURLWithPath: path))

        return path
    }

    private func existingOutput(
        in directory: TemporaryDirectory,
        name: String
    ) throws -> String {
        let path = directory.file(name)
        try Self.existing.write(to: URL(fileURLWithPath: path))

        return path
    }

    // The request stops with `error` before any role writes, and an existing output keeps its bytes.
    private func expectStop(
        _ request: TranscodeRequest,
        facts: [String: ProbedMedia],
        colorReading: ColorReading = .formulas(.srgb),
        error: TranscodeError
    ) throws {
        let log = RoleCallLog()
        let sut = transcoder(log: log, facts: facts, colorReading: colorReading)

        let thrown = #expect(throws: TranscodeError.self) {
            try sut.transcode(request)
        }

        #expect(thrown == error)
        #expect(log.calls.allSatisfy {
            switch $0 {
            case .checkMedia, .checkTarget, .checkImageTarget, .checkSoundTarget:
                true

            default:
                false
            }
        })
        #expect(try Data(contentsOf: URL(fileURLWithPath: request.output)) == Self.existing)
    }
}
