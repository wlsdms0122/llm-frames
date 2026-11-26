//
//  Renderer.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Draws the display list of one output frame.
package protocol Renderer: Sendable {
    // Refuses a list holding anything the renderer cannot draw, naming the first such thing and its place in the list,
    // sample lists among them for a renderer that cannot draw their mean.
    func check(_ list: DisplayList) throws

    // The bytes the run's budget counts the media pictures of pixels the list reads at, each picture once, as the
    // renderer keeps them while it draws the list (FRAMES-30 The budget).
    func pictureBytes(of list: DisplayList) throws -> Int

    // A list given as sample lists is the mean of their pictures (FRAMES-29). The frame is a bitmap or a surface
    // (FRAMES-21 Pictures). Once it is drawn, the renderer gives the decoder it reads through the media frames it
    // showed, `MediaDecoder.frameRendered(showing:)`, so the decoder ends the plays it did not show (FRAMES-21 Rules).
    func frame(of list: DisplayList) throws -> Pixels
}
