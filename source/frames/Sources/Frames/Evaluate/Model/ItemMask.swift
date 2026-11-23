//
//  ItemMask.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// One mask of a display item. `geometry` is a path outline, a path always closed, `transform` the map from its
// coordinates to output pixels of the list that holds the item, and `feather` the standard deviation in output pixels
// of the Gaussian blur of its coverage. Its value is that blurred coverage, 1 minus it when `isInverted`, and `mode`
// says how it combines with the masks before it.
package struct ItemMask: Equatable, Sendable {
    // MARK: - Property
    // How far past its geometry, in multiples of its feather, a mask's blurred coverage is drawn: past four standard
    // deviations a Gaussian holds less than a ten-thousandth of its weight.
    package static let featherReach = 4.0

    package let geometry: PathGeometry
    package let transform: AffineTransform
    package let feather: Double
    package let isInverted: Bool
    package let mode: MaskMode

    // MARK: - Initializer
    package init(
        geometry: PathGeometry,
        transform: AffineTransform,
        feather: Double,
        isInverted: Bool,
        mode: MaskMode
    ) {
        self.geometry = geometry
        self.transform = transform
        self.feather = feather
        self.isInverted = isInverted
        self.mode = mode
    }

    // MARK: - Public
    // MARK: - Private
}
