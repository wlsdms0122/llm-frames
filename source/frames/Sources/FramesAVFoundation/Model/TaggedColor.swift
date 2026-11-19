//
//  TaggedColor.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/20/26.
//

import Frames

// The colour a picture's file is tagged with, as the decoder reads it: what converts its encoded values, or why no
// fixed formula does, the maximum luminance of its mastering display in cd/m² where it carries SMPTE ST 2086 metadata,
// and its facts as `probe` reports them.
struct TaggedColor: Equatable, Sendable {
    // MARK: - Property
    let color: Result<MediaColor, ColorRefusal>
    let masteringDisplayPeak: Double?
    let probed: ProbedColorSpace

    // How the file's pictures are taken to working values: by the formulas of what it names, or by the platform's
    // colour management where no fixed formula converts it.
    var colorReading: ColorReading {
        Self.reading(of: color)
    }

    // MARK: - Initializer
    init(
        color: Result<MediaColor, ColorRefusal>,
        masteringDisplayPeak: Double? = nil,
        probed: ProbedColorSpace
    ) {
        self.color = color
        self.masteringDisplayPeak = masteringDisplayPeak
        self.probed = probed
    }

    // A video's, by the code points its format names, each nil where it leaves it out.
    init(
        primaries: Int?,
        transfer: Int?,
        matrix: Int?,
        bitDepth: Int,
        masteringDisplayPeak: Double?
    ) {
        let codePoints = CodePoints(
            colorPrimaries: primaries ?? 2,
            transferCharacteristics: transfer ?? 2,
            matrixCoefficients: matrix ?? 2
        )
        let color: Result<MediaColor, ColorRefusal> = MediaColor(codePoints: codePoints)
            .map { .success($0) } ?? .failure(.reservedCodePoints(codePoints))

        self.init(
            color: color,
            masteringDisplayPeak: masteringDisplayPeak,
            probed: ProbedColorSpace(
                reading: Self.reading(of: color),
                primaries: primaries,
                transfer: transfer,
                matrix: matrix,
                bitDepth: bitDepth,
                isHighDynamicRange: [16, 18].contains(transfer)
            )
        )
    }

    // An image's, by its ICC profile, nil for an untagged image, which is `srgb`.
    init(
        profile: ICCProfileReader?,
        bitDepth: Int,
        masteringDisplayPeak: Double?
    ) {
        let color = profile?.color() ?? .success(.space(.srgb))
        let row = profile == nil ? nil : (try? color.get().colorSpace)?.codePoints
        let isHighDynamicRange: Bool = switch try? color.get() {
        case let .space(space)?:
            space.isHighDynamicRange

        case let .codePoints(codePoints)?:
            [16, 18].contains(codePoints.transferCharacteristics)

        case .profile?, nil:
            false
        }

        self.init(
            color: color,
            masteringDisplayPeak: masteringDisplayPeak,
            probed: ProbedColorSpace(
                reading: Self.reading(of: color),
                primaries: row?.colorPrimaries,
                transfer: row?.transferCharacteristics,
                matrix: nil,
                bitDepth: bitDepth,
                isHighDynamicRange: isHighDynamicRange
            )
        )
    }

    // MARK: - Public
    // MARK: - Private
    private static func reading(of color: Result<MediaColor, ColorRefusal>) -> ColorReading {
        switch color {
        case let .success(color):
            .formulas(color.colorSpace)

        case .failure:
            .platform
        }
    }
}
