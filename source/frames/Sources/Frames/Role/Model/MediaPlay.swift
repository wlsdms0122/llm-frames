//
//  MediaPlay.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// The play a frame of raster media is read in, the showing of a file by one time map (FRAMES-21 Rules). `place` is
// the place in the document of the clip, transition cover or transition matte whose time map picks the frame,
// continued into a nested sequence from the clip that holds it, so each use of a compound clip or a template has plays
// of its own. `file` is the one play of a file read at no place in a document: by a command that reads one file, as
// `extract`, `track`, `ocr` and `transcode` read a video and the frames `sheet` lays out of a file are, and the still a
// `displace` op reads as its map, at its one frame, in each frame of a document that shows it. A play ends with the
// first frame rendered that does not show it, and one read with no frame rendered lasts for the command.
package enum MediaPlay: Hashable, Sendable {
    case place(String)
    case file

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
