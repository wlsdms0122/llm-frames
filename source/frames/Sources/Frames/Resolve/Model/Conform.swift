//
//  Conform.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a crop fills the frame: `fit` shows the whole crop, and `fill` fills the frame and cuts what overflows.
enum Conform: String, Equatable, Sendable {
    case fit
    case fill
}
