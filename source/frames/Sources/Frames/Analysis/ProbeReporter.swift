//
//  ProbeReporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// Probes a media file, an image sequence directory or a page of a PDF through the decoder and reports it as `probe`
// prints it. A file that is there but is no media stops with the decoder's reason, and a page with the reason its
// decoder refuses it. A PDF of more than one page with no page named reports its page count alone (FRAMES-23).
package struct ProbeReporter: Sendable {
    // MARK: - Property
    private let mediaFacts: any MediaFactProvider

    // MARK: - Initializer
    package init(mediaFacts: any MediaFactProvider) {
        self.mediaFacts = mediaFacts
    }

    // MARK: - Public
    package func report(
        of path: String,
        page: Int? = nil
    ) throws -> ProbeReport {
        if page == nil, isDirectory(path) {
            guard let sequence = try mediaFacts.probedImageSequence(at: path) else {
                throw AnalysisError.missingMedia(file: path)
            }

            return ProbeReport(sequence)
        }
        switch try mediaFacts.commandPage(page, of: path) {
        case let .page(number):
            guard let probed = try mediaFacts.probedPage(number, of: path) else {
                throw AnalysisError.missingMedia(file: path)
            }

            return ProbeReport(probed)

        case let .unnamed(pageCount):
            return ProbeReport(pageCount: pageCount)

        case .notPDF:
            break
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
