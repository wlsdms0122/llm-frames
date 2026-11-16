//
//  Renderer.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Draws the display list of one output frame.
package protocol Renderer: Sendable {
    // Refuses a list holding anything the renderer cannot draw, naming the first such thing and its place in the list.
    func check(_ list: DisplayList) throws

    func frame(of list: DisplayList) throws -> Bitmap
}
