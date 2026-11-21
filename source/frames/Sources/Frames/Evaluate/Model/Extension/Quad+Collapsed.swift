//
//  Quad+Collapsed.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

extension Quad {
    // MARK: - Property
    // Four equal points at [0, 0], the corner pin of a clip's group in a sample list where its corner pin draws nothing
    // (FRAMES-20 Pictures). No homography from a rectangle with area reaches it, so the group draws nothing there.
    package static let collapsed = Quad(Rectangle(x: 0, y: 0, width: 0, height: 0))

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
