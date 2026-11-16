//
//  CubeLUT.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// A 3D LUT as a `.cube` file writes it: `size` entries along each axis over the input domain from `domainMin` to
// `domainMax`, each axis's minimum and maximum as red, green and blue.
package struct CubeLUT: Equatable, Sendable {
    // MARK: - Property
    package let title: String?
    package let size: Int
    package let domainMin: [Double]
    package let domainMax: [Double]
    // `size`³ entries of red, green and blue, red varying fastest, then green, then blue.
    package let values: [Double]

    // MARK: - Initializer
    package init(
        title: String?,
        size: Int,
        domainMin: [Double],
        domainMax: [Double],
        values: [Double]
    ) {
        self.title = title
        self.size = size
        self.domainMin = domainMin
        self.domainMax = domainMax
        self.values = values
    }

    // MARK: - Public
    // MARK: - Private
}
