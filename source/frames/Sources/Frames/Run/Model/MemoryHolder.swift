//
//  MemoryHolder.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// A holder that a run's budget counts, in the order the run report gives them (FRAMES-30 The budget): the decoder's
// open readers, each at the charge the decoder sets for it, the frames the decoder has read ahead and not given, the
// decoded frames a turn holds for later asks, the media pictures the renderer keeps, the output frames in flight, and
// the run's mixed sound.
package enum MemoryHolder: String, CaseIterable, Equatable, Sendable {
    case readers
    case readAhead
    case turns
    case pictures
    case frames
    case sound

    // MARK: - Property
    // The holder's name in the run report and in messages.
    package var name: String {
        rawValue
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
