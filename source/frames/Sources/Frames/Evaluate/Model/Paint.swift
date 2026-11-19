//
//  Paint.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// What a fill or a stroke and its arrowheads are painted with.
package enum Paint: Equatable, Sendable {
    case color(Color)
    case gradient(Gradient)
}
