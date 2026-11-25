//
//  RunReportTests.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

import Testing

@testable import Frames

@Suite("RunReport Tests")
struct RunReportTests {
    // MARK: - Property
    private let machine = MachineFacts(chip: "Apple M2 Pro", cores: 12, operatingSystem: "macOS 26.2.0")
    private let roles = RoleNames(decoder: "avfoundation", renderer: "quartz", mixer: "avfoundation", encoder: "avfoundation")
    private let video = MediaFile(path: "/abs/run.mp4", frameTimes: [0, 0.5])

    // MARK: - Initializer
    // MARK: - Test
    @Test("the render's thread's stages, waiting and other add up to the run's seconds, the decoder's reading inside a stage counted once as decode and the writers' stages beside the sum")
    func addsUpStages() throws {
        // Given
        let clock = ManualClock()
        let decoder = TimedDecoder(clock: clock, readSeconds: 0.25)
        let recorder = RunRecorder(clock: { clock.seconds })
        clock.advance(by: 1)
        recorder.measure(.resolve, reading: decoder) { clock.advance(by: 2) }
        try recorder.measure(.draw, reading: decoder) {
            clock.advance(by: 0.5)
            _ = try decoder.picture(of: video, atFrame: 0, reading: .tagged)
        }
        recorder.measureWaitingOnEncoder { clock.advance(by: 0.75) }
        clock.advance(by: 0.125)

        // When
        let sut = RunReport(
            run: RenderRun(frames: 1, files: [file("/abs/out.mov", outputConversion: 3, encode: 4)]),
            seconds: recorder.elapsed,
            cpuSeconds: 6,
            peakMemory: 1_048_576,
            machine: machine,
            roles: roles,
            recorder: recorder,
            readings: decoder.readings()
        )

        // Then
        #expect(sut.seconds == 4.625)
        #expect(sut.stages[.resolve] == 2)
        #expect(sut.stages[.draw] == 0.5)
        #expect(sut.stages[.decode] == 0.25)
        #expect(sut.stages[.outputConversion] == 3)
        #expect(sut.stages[.encode] == 4)
        #expect(sut.readAhead == StageTimes())
        #expect(sut.waitingOnEncoder == 0.75)
        #expect(sut.waitingOnDecoder == 0)
        #expect(sut.other == 1.125)
        #expect(sut.stages.renderThreadSeconds + sut.waitingOnEncoder + sut.other == sut.seconds)
    }

    @Test("a picture read ahead beside the render's thread is decode and workingConversion and readAhead, taken from no stage, the wait for it is the decoder's waiting, the sum less readAhead is the run's seconds, and the picture read ahead and never asked for is decoded and not read")
    func addsUpReadAhead() throws {
        // Given
        let clock = ManualClock()
        let decoder = ReadAheadDecoder(
            clock: clock,
            readSeconds: 0.25,
            waitSeconds: 0.0625,
            aheadDecodeSeconds: 0.375,
            aheadConversionSeconds: 0.125
        )
        let recorder = RunRecorder(clock: { clock.seconds })
        for index in 0..<2 {
            try recorder.measure(.draw, reading: decoder) {
                clock.advance(by: 0.5)
                _ = try decoder.picture(of: video, atFrame: index, reading: .tagged)
            }
        }
        recorder.measureWaitingOnEncoder { clock.advance(by: 0.75) }

        // When
        let sut = RunReport(
            run: RenderRun(frames: 2, files: [file("/abs/out.mov", outputConversion: 3, encode: 4)]),
            seconds: recorder.elapsed,
            cpuSeconds: 6,
            peakMemory: 1_048_576,
            machine: machine,
            roles: roles,
            recorder: recorder,
            readings: decoder.readings()
        )

        // Then
        #expect(sut.seconds == 2.0625)
        #expect(sut.stages[.draw] == 1)
        #expect(sut.stages[.decode] == 1)
        #expect(sut.stages[.workingConversion] == 0.25)
        #expect(sut.readAhead[.decode] == 0.75)
        #expect(sut.readAhead[.workingConversion] == 0.25)
        #expect(sut.waitingOnDecoder == 0.0625)
        #expect(sut.waitingOnEncoder == 0.75)
        #expect(sut.other == 0)
        let renderThread = sut.stages.renderThreadSeconds - sut.readAhead.renderThreadSeconds
        #expect(renderThread + sut.waitingOnEncoder + sut.waitingOnDecoder + sut.other == sut.seconds)
        #expect(sut.media.map(\.framesRead) == [2])
        #expect(sut.media.map(\.framesDecoded) == [3])
    }

    @Test("the machine output is the render object FRAMES-23 gives, every field there and every stage in its order")
    func writesMachineOutput() throws {
        // Given
        let clock = ManualClock()
        let recorder = RunRecorder(clock: { clock.seconds })
        recorder.measure(.resolve, reading: TimedDecoder(clock: clock, readSeconds: 0)) { clock.advance(by: 0.5) }
        recorder.measureWaitingOnEncoder { clock.advance(by: 1.25) }
        clock.advance(by: 0.25)
        let media = [
            MediumReading(path: "/abs/run.mp4", page: nil, conversion: .space(.rec709), pixelFormat: "16-bit float RGBA", framesRead: 2, framesDecoded: 3, reopened: 1),
            MediumReading(path: "/abs/deck.pdf", page: 2, conversion: .identity, pixelFormat: "32-bit float RGBA", framesRead: 1, framesDecoded: 1, reopened: 0),
            MediumReading(path: "/abs/hlg.mov", page: nil, conversion: .hybridLogGamma, pixelFormat: "16-bit float RGBA", framesRead: 1, framesDecoded: 1, reopened: 0)
        ]
        var decoded = StageTimes()
        decoded.add(0.125, to: .decode)
        decoded.add(0.0625, to: .workingConversion)
        var ahead = StageTimes()
        ahead.add(0.0625, to: .decode)
        let files = [
            file("/abs/out.mov", outputConversion: 0.375, encode: 0.5, usesHardware: true),
            FileEncoding(path: "/abs/out.mp4", codec: "H.264", usesHardware: true, seconds: StageTimes())
        ]

        // When
        let sut = RunReport(
            run: RenderRun(frames: 3, files: files),
            seconds: recorder.elapsed,
            cpuSeconds: 3,
            peakMemory: 1_048_576,
            machine: machine,
            roles: roles,
            recorder: recorder,
            readings: MediaReadings(media: media, seconds: decoded, readAhead: ahead, waiting: 0.125)
        )

        // Then
        let expected = #"""
            {"render": "0.1.0", "frames": 3, "seconds": 2, "cpuSeconds": 3, "fps": 1.5, "cores": 1.5, \#
            "peakMemory": 1048576, "machine": {"chip": "Apple M2 Pro", "cores": 12, "os": "macOS 26.2.0"}, \#
            "roles": {"decoder": "avfoundation", "renderer": "quartz", "mixer": "avfoundation", "encoder": "avfoundation"}, \#
            "stages": {"resolve": 0.5, "check": 0, "evaluate": 0, "mix": 0, "decode": 0.125, "workingConversion": 0.0625, \#
            "draw": 0, "outputConversion": 0.375, "encode": 0.5}, "readAhead": {"decode": 0.0625, "workingConversion": 0}, \#
            "waiting": {"encoder": 1.25, "decoder": 0.125}, "other": 0, \#
            "media": [{"path": "/abs/run.mp4", "page": null, "colorSpace": "rec709", "conversion": "space", \#
            "pixelFormat": "16-bit float RGBA", "framesRead": 2, "framesDecoded": 3, "reopened": 1}, \#
            {"path": "/abs/deck.pdf", "page": 2, "colorSpace": "srgb", "conversion": "none", \#
            "pixelFormat": "32-bit float RGBA", "framesRead": 1, "framesDecoded": 1, "reopened": 0}, \#
            {"path": "/abs/hlg.mov", "page": null, "colorSpace": null, "conversion": "hlg", \#
            "pixelFormat": "16-bit float RGBA", "framesRead": 1, "framesDecoded": 1, "reopened": 0}], \#
            "files": [{"path": "/abs/out.mov", "codec": "ProRes 422 HQ", "hardware": true}, \#
            {"path": "/abs/out.mp4", "codec": "H.264", "hardware": true}]}
            """#
        #expect(sut.machineOutput.written == expected)
    }

    // MARK: - Private
    private func file(
        _ path: String,
        outputConversion: Double,
        encode: Double,
        usesHardware: Bool = false
    ) -> FileEncoding {
        var seconds = StageTimes()
        seconds.add(outputConversion, to: .outputConversion)
        seconds.add(encode, to: .encode)

        return FileEncoding(path: path, codec: "ProRes 422 HQ", usesHardware: usesHardware, seconds: seconds)
    }
}
