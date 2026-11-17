//
//  CommandContextTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
import Testing

@testable import FramesCommand

@Suite("CommandContext Tests")
struct CommandContextTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("the exporter stops when the shaping provider does not find the face time labels are set in")
    func refusesMissingLabelFace() throws {
        // Given
        let real = try RoleFactory().roles(for: .none)
        let roles = Roles(
            decoder: real.decoder,
            renderer: real.renderer,
            mixer: real.mixer,
            encoder: real.encoder,
            ocr: real.ocr,
            shaper: FacelessShaper(),
            tracker: real.tracker
        )
        let sut = CommandContext(
            options: .none,
            roles: roles,
            output: OutputRecorder().output,
            environment: CommandEnvironment(
                variables: [:],
                shippedPacks: URL(fileURLWithPath: "/nonexistent", isDirectory: true),
                standardInput: { Data() }
            )
        )

        // When
        let error = #expect(throws: CommandError.self) {
            try sut.exporter()
        }

        // Then
        #expect(
            error == .missingLabelFace(name: "HelveticaNeue-Medium", file: "/System/Library/Fonts/HelveticaNeue.ttc")
        )
        #expect(
            error?.description == #""/System/Library/Fonts/HelveticaNeue.ttc": the file has no face "HelveticaNeue-Medium", which time labels are set in"#
        )
    }

    // MARK: - Private
}
