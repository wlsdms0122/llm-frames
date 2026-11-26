//
//  MediaPlay.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// The play a frame of raster media is read in, the showing of a file by one time map (FRAMES-21 Rules). `place` is
// the place in the document of the clip, transition cover or transition matte whose time map picks the frame,
// continued into a nested sequence from the clip that holds it. `file` is the one play of a file read on its own: by a
// command that reads one file, as the frames `sheet` lays out of a file are, and a displacement map, read at its one
// frame.
package enum MediaPlay: Hashable, Sendable {
    case place(String)
    case file

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
