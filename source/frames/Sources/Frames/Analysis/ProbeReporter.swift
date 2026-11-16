//
//  ProbeReporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// Probes a media file, or an image sequence directory, through the decoder and reports it as `probe` prints it. A
// file that is there but is no media stops with the decoder's reason.
package struct ProbeReporter: Sendable {
    // MARK: - Property
    private let mediaFacts: any MediaFactProvider

    // MARK: - Initializer
    package init(mediaFacts: any MediaFactProvider) {
        self.mediaFacts = mediaFacts
    }

    // MARK: - Public
    package func report(of path: String) throws -> ProbeReport {
        if isDirectory(path) {
            guard let sequence = try mediaFacts.probedImageSequence(at: path) else {
                throw AnalysisError.missingMedia(file: path)
            }

            return ProbeReport(sequence)
        }
        guard let probed = try mediaFacts.probedMedia(of: path) else { throw AnalysisError.missingMedia(file: path) }

        return ProbeReport(probed)
    }

    // MARK: - Private
    private func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
