//
//  FontStyle.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A face's style as its OS/2 table declares it, which CSS reads as `font-style`.
package enum FontStyle: String, Equatable, Sendable {
    case upright
    case italic
    case oblique
}
