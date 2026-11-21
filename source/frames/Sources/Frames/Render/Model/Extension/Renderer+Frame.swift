//
//  Renderer+Frame.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A renderer's check of one frame's list. A renderer sees a list and not the frame it is of, so a refusal of a list
// given as samples is given the frame's instant here, which names the frame that holds them (FRAMES-29).
extension Renderer {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func check(
        _ list: DisplayList,
        ofFrameAt time: Double
    ) throws {
        do {
            try check(list)
        } catch {
            guard list.samples != nil else { throw error }

            throw RenderError.sampledFrame(time: time, reason: String(describing: error))
        }
    }

    // MARK: - Private
}
