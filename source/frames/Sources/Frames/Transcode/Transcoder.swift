//
//  Transcoder.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// Writes a media file again, smaller, through the roles: the input is judged by its contents through the decoder's
// probe, read through the decoder and written with the encoder. An image goes to a JPEG, HEIC or PNG, a sound to AAC
// in an .m4a, and a video to H.264 or HEVC in an .mp4, .mov or .m4v with its sound in AAC, or to its sound alone in an
// .m4a. Pictures are taken as the decoder displays them, turned, and nothing else of the input is carried over.
// Everything that can stop does before anything is written, in this order: `--max`, the input, the paths, the output
// extension, `--codec`, a video's sound or frame rate, the size `--max` gives a video, the decoder on the input, and the
// encoder on the target and on the sound read for it. An existing output file is removed only then.
package struct Transcoder: Sendable {
    // MARK: - Property
    private static let imageExtensions = ["jpg", "heic", "png"]
    private static let soundExtensions = ["m4a"]
    private static let videoExtensions = ["mp4", "mov", "m4v", "m4a"]

    private let decoder: any MediaDecoder
    private let facts: any MediaFactProvider
    private let encoder: any Encoder

    // MARK: - Initializer
    package init(
        decoder: any MediaDecoder,
        facts: any MediaFactProvider,
        encoder: any Encoder
    ) {
        self.decoder = decoder
        self.facts = facts
        self.encoder = encoder
    }

    // MARK: - Public
    package func transcode(_ request: TranscodeRequest) throws -> TranscodeResult {
        if let maximumSide = request.maximumSide, maximumSide <= 0 {
            throw TranscodeError.maximumSide(maximumSide)
        }
        guard let media = try facts.probedMedia(of: request.input) else {
            throw TranscodeError.missingInput(path: request.input)
        }
        try checkPaths(of: request)
        let sourceByteCount = try byteCount(of: request.input)

        let format: TranscodeFormat = switch media.kind {
        case .image:
            try transcodeImage(media, for: request)

        case .audio:
            try transcodeSound(media, for: request)

        case .video:
            try transcodeVideo(media, for: request)

        case .sequence:
            throw TranscodeError.unsupportedInput(path: request.input)
        }

        return TranscodeResult(
            path: request.output,
            byteCount: try byteCount(of: request.output),
            sourceByteCount: sourceByteCount,
            format: format
        )
    }

    // MARK: - Private
    private func transcodeImage(
        _ media: ProbedMedia,
        for request: TranscodeRequest
    ) throws -> TranscodeFormat {
        try checkExtension(of: request, kind: .image, allowed: Self.imageExtensions)
        try checkNoCodec(in: request)
        guard let size = media.size else { throw TranscodeError.unsupportedInput(path: request.input) }

        let file = MediaFile(path: request.input, size: size)
        let fitted = outputSize(of: size, maximumSide: request.maximumSide, isVideo: false)
        let target: ImageTarget = switch request.outputExtension {
        case "jpg":
            .jpeg(path: request.output, size: fitted, quality: request.quality)

        case "heic":
            .heic(path: request.output, size: fitted, quality: request.quality)

        default:
            .png(path: request.output, size: fitted)
        }
        try decoder.check(file)
        try encoder.check(target)

        let picture = try decoder.picture(of: file, atFrame: 0)
        try removeExisting(request.output)
        try encoder.writeImage(picture, for: target)

        return TranscodeFormat(target)
    }

    private func transcodeSound(
        _ media: ProbedMedia,
        for request: TranscodeRequest
    ) throws -> TranscodeFormat {
        try checkExtension(of: request, kind: .audio, allowed: Self.soundExtensions)
        try checkNoCodec(in: request)

        try writeSound(of: MediaFile(path: request.input), duration: media.duration, for: request)

        return .aac
    }

    private func transcodeVideo(
        _ media: ProbedMedia,
        for request: TranscodeRequest
    ) throws -> TranscodeFormat {
        try checkExtension(of: request, kind: .video, allowed: Self.videoExtensions)
        guard let size = media.size else { throw TranscodeError.unsupportedInput(path: request.input) }
        let file = MediaFile(path: request.input, fps: media.fps, size: size, frameTimes: media.frames)

        if request.outputExtension == "m4a" {
            try checkNoCodec(in: request)
            guard media.hasSound else { throw TranscodeError.noSound(path: request.output, input: request.input) }

            try writeSound(of: file, duration: media.duration, for: request)

            return .aac
        }

        guard let fps = media.fps, fps > 0 else { throw TranscodeError.noFrameRate(path: request.input) }
        try checkVideoSize(of: size, for: request)
        let codec = request.codec ?? .h264
        let target = EncodeTarget.compressed(
            path: request.output,
            codec: codec,
            quality: request.quality,
            size: outputSize(of: size, maximumSide: request.maximumSide, isVideo: true)
        )
        try decoder.check(file)
        let frameCount = frameCount(duration: media.duration, fps: fps)
        let sound = media.hasSound ? try decoder.sound(of: file, from: 0, to: Double(frameCount) / fps) : nil
        try encoder.check(target)
        // A video's sound goes to AAC as a sound file's does, so the encoder checks its layout the same way.
        if let sound {
            try encoder.check(
                SoundTarget(
                    path: request.output,
                    quality: request.quality,
                    layout: sound.layout,
                    sampleRate: sound.sampleRate
                )
            )
        }

        try removeExisting(request.output)

        // A writer let go before it finishes, as when a frame cannot be read, cancels and removes its file.
        let writer = try encoder.videoWriter(for: target, size: size, fps: fps, sound: sound)
        for index in 0..<frameCount {
            try writer.append(decoder.picture(of: file, atFrame: file.frameIndex(at: Double(index) / fps)))
        }
        try writer.finish()

        return .video(codec: codec, hasSound: sound != nil)
    }

    private func writeSound(
        of file: MediaFile,
        duration: Double,
        for request: TranscodeRequest
    ) throws {
        try decoder.check(file)
        let sound = try decoder.sound(of: file, from: 0, to: duration)
        let target = SoundTarget(
            path: request.output,
            quality: request.quality,
            layout: sound.layout,
            sampleRate: sound.sampleRate
        )
        try encoder.check(target)

        try removeExisting(request.output)
        try encoder.writeSound(sound, for: target)
    }

    // An output that does not exist yet is no file the input is. One that does is compared with symbolic links
    // resolved, and then as the file system names it, so a hard link or another case of the same name stops too.
    private func checkPaths(of request: TranscodeRequest) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: request.output, isDirectory: &isDirectory) else { return }
        guard !isDirectory.boolValue else { throw TranscodeError.outputDirectory(path: request.output) }

        let input = URL(fileURLWithPath: request.input).resolvingSymlinksInPath().path
        let output = URL(fileURLWithPath: request.output).resolvingSymlinksInPath().path
        guard input != output, !isSameFile(input, output) else { throw TranscodeError.sameFile(path: request.output) }
    }

    private func isSameFile(
        _ first: String,
        _ second: String
    ) -> Bool {
        guard
            let firstAttributes = try? FileManager.default.attributesOfItem(atPath: first),
            let secondAttributes = try? FileManager.default.attributesOfItem(atPath: second),
            let firstNumber = firstAttributes[.systemFileNumber] as? Int,
            let secondNumber = secondAttributes[.systemFileNumber] as? Int,
            let firstDevice = firstAttributes[.systemNumber] as? Int,
            let secondDevice = secondAttributes[.systemNumber] as? Int
        else {
            return false
        }

        return firstNumber == secondNumber && firstDevice == secondDevice
    }

    private func checkExtension(
        of request: TranscodeRequest,
        kind: MediaKind,
        allowed: [String]
    ) throws {
        guard allowed.contains(request.outputExtension) else {
            throw TranscodeError.outputExtension(
                path: request.output,
                input: request.input,
                kind: kind,
                allowed: allowed
            )
        }
    }

    private func checkNoCodec(in request: TranscodeRequest) throws {
        guard request.codec == nil else { throw TranscodeError.codecWithoutVideo(path: request.output) }
    }

    // A video's side is at least 2 pixels, the least even number, so a source or a cap that rounds a side below it
    // stops rather than writing a video larger than either. The cap is named only when it shrank the video.
    private func checkVideoSize(
        of size: Size,
        for request: TranscodeRequest
    ) throws {
        let fitted = outputSize(of: size, maximumSide: request.maximumSide, isVideo: false)
        guard fitted.width < 2 || fitted.height < 2 else { return }

        let shrinking = request.maximumSide.flatMap { Double($0) < max(size.width, size.height) ? $0 : nil }
        throw TranscodeError.undersizedVideo(path: request.output, maximumSide: shrinking, size: fitted)
    }

    // `size` with its longer side capped at `maximumSide`, never enlarged, each side rounded to whole pixels. A
    // video's odd side goes down to the even number below it, so it exceeds neither the source nor the cap.
    private func outputSize(
        of size: Size,
        maximumSide: Int?,
        isVideo: Bool
    ) -> Size {
        let longer = max(size.width, size.height)
        let scale = maximumSide.map { min(1, Double($0) / longer) } ?? 1

        return Size(
            width: side(size.width * scale, isVideo: isVideo),
            height: side(size.height * scale, isVideo: isVideo)
        )
    }

    private func side(
        _ length: Double,
        isVideo: Bool
    ) -> Double {
        let whole = max(length.rounded(), 1)
        guard isVideo else { return whole }

        return whole - whole.truncatingRemainder(dividingBy: 2)
    }

    // Frame k is written at k / fps for every k whose time, measured to the microsecond, is before `duration`, and
    // frame 0 always, as a sequence's frames are.
    private func frameCount(
        duration: Double,
        fps: Double
    ) -> Int {
        let end = duration.roundedTime
        var count = 1
        while (Double(count) / fps).roundedTime < end {
            count += 1
        }

        return count
    }

    private func removeExisting(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else { return }

        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            throw TranscodeError.unremovable(path: path, reason: error.localizedDescription)
        }
    }

    private func byteCount(of path: String) throws -> Int {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int else {
            throw TranscodeError.unmeasurable(path: path)
        }

        return size
    }
}
