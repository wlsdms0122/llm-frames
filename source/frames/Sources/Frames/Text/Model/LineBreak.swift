//
//  LineBreak.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Whether a line may or must break before a scalar. `insideWord` is a break UAX #14 allows between two letter units of
// one word, which a line takes only to break a word wider than itself.
enum LineBreak: Equatable, Sendable {
    case prohibited
    case allowed
    case insideWord
    case mandatory
}
