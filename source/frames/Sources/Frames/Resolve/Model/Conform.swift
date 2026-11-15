//
//  Conform.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a crop fills the content rect: `fit` shows the whole crop, and `fill` fills the rect and cuts what overflows.
enum Conform: String, Equatable, Sendable {
    case fit
    case fill
}
