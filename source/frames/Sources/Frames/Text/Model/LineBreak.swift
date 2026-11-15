//
//  LineBreak.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Whether a line may or must break before a scalar.
enum LineBreak: Equatable, Sendable {
    case prohibited
    case allowed
    case mandatory
}
