//
//  ResizeForm.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a `resize` operation gives the new size: a factor, or the width or height the canvas takes.
enum ResizeForm: Equatable, Sendable {
    case scale(Double)
    case width(Double)
    case height(Double)
}
