//
//  TrackDataRefusal.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Why track data stops at resolve (FRAMES-12): a written quad is a value, checked as every written value is.
enum TrackDataRefusal: Equatable, Sendable {
    case outsideMedia
    case notConvex
    case otherOrientation
    case outOfOrder
    case sameFrame
    case gap
    case noTarget

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
