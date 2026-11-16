//
//  ResolvedDocument.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A resolved document as a model: a sequence, or an image or layout document. Resolve builds it from its plan and
// writes it, and evaluation reads it, whether it came from resolve in the same process or from a file.
enum ResolvedDocument: Equatable, Sendable {
    case sequence(ResolvedSequence)
    case picture(ResolvedPicture)
}
