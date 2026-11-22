//
//  PlaneAlignment.swift
//  FramesTracker
//
//  Created by JSilver on 11/22/26.
//

import simd

// Where a template lies on a frame: the homography from the target's frame to this one in media pixels, the
// zero-mean normalised cross-correlation of the template with the frame over the pixels the robust weights keep, from
// -1 to 1, and the share of the template's pixels that are inliers, whose residuals lie within Tukey's band of the
// template's noise, from 0 to 1.
struct PlaneAlignment: Sendable {
    // MARK: - Property
    // Scaled to w = 1 at the target's centroid, so the target's centroid lies in front of the horizon.
    let homography: simd_double3x3
    let correlation: Double
    let inlierRatio: Double

    // MARK: - Initializer
    init(
        homography: simd_double3x3,
        correlation: Double,
        inlierRatio: Double
    ) {
        self.homography = homography
        self.correlation = correlation
        self.inlierRatio = inlierRatio
    }

    // MARK: - Public
    // MARK: - Private
}
