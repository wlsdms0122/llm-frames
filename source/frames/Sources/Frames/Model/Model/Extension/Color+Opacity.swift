//
//  Color+Opacity.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

extension Color {
    // MARK: - Property
    var isOpaque: Bool {
        alpha >= 1
    }

    var isTransparent: Bool {
        alpha <= 0
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
