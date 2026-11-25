//
//  RoleFactory.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames
import FramesAVFoundation
import FramesCoreText
import FramesQuartz
import FramesTracker
import FramesVision

// Builds the roles and providers by the names the global options give. The decoder is built once and handed to
// everything that reads media, so a file is opened the same way by all of them.
struct RoleFactory: Sendable {
    // MARK: - Property
    private let decoders = RoleTable<@Sendable () -> any MediaDecoder & MediaFactProvider>(
        role: "decoder",
        option: "--decoder",
        defaultName: "avfoundation",
        builders: ["avfoundation": { AVFoundationDecoder() }]
    )
    private let renderers = RoleTable<@Sendable (any MediaDecoder) -> any Renderer>(
        role: "renderer",
        option: "--renderer",
        defaultName: "quartz",
        builders: ["quartz": { QuartzRenderer(decoder: $0) }]
    )
    private let mixers = RoleTable<@Sendable (any MediaDecoder) -> any Mixer>(
        role: "mixer",
        option: "--mixer",
        defaultName: "avfoundation",
        builders: ["avfoundation": { AVFoundationMixer(decoder: $0) }]
    )
    private let encoders = RoleTable<@Sendable () -> any Frames.Encoder>(
        role: "encoder",
        option: "--encoder",
        defaultName: "avfoundation",
        builders: ["avfoundation": { AVFoundationEncoder() }]
    )
    private let ocrs = RoleTable<@Sendable (any MediaDecoder) -> any OCRProvider>(
        role: "OCR provider",
        option: "--ocr",
        defaultName: "vision",
        builders: ["vision": { VisionOCR(decoder: $0) }]
    )
    private let shapers = RoleTable<@Sendable () -> any ShapingProvider>(
        role: "shaping provider",
        option: "--shaper",
        defaultName: "coretext",
        builders: ["coretext": { CoreTextShaper() }]
    )
    private let trackers = RoleTable<@Sendable (any MediaDecoder) -> any TrackerProvider>(
        role: "tracker provider",
        option: "--tracker",
        defaultName: "point",
        builders: ["planar": { PlanarTracker(decoder: $0) }, "point": { PointTracker(decoder: $0) }]
    )

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // The global options that pick each role and provider, in the order usage writes them.
    var rules: [OptionRule] {
        [decoders.rule, renderers.rule, mixers.rule, encoders.rule, shapers.rule, trackers.rule, ocrs.rule]
    }

    // The names of the implementations that fill the four roles.
    func names(for options: GlobalOptions) -> RoleNames {
        RoleNames(
            decoder: decoders.name(options.decoder),
            renderer: renderers.name(options.renderer),
            mixer: mixers.name(options.mixer),
            encoder: encoders.name(options.encoder)
        )
    }

    func roles(for options: GlobalOptions) throws -> Roles {
        let decoder = try decoders.builder(named: options.decoder)()

        return Roles(
            decoder: decoder,
            renderer: try renderers.builder(named: options.renderer)(decoder),
            mixer: try mixers.builder(named: options.mixer)(decoder),
            encoder: try encoders.builder(named: options.encoder)(),
            ocr: try ocrs.builder(named: options.ocr)(decoder),
            shaper: try shapers.builder(named: options.shaper)(),
            tracker: try trackers.builder(named: options.tracker)(decoder)
        )
    }

    // MARK: - Private
}
