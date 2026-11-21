//
//  ProbedKind.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// What a reference names, as far as the key check needs it: a PDF, by its page count, or media of a kind, a document
// among them as a sequence.
enum ProbedKind: Equatable, Sendable {
    case pdf(pageCount: Int)
    case media(MediaKind)
}
