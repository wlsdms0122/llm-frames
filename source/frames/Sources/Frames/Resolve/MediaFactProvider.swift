//
//  MediaFactProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What the probe tells about the media a document names, as far as time needs it.
protocol MediaFactProvider: Sendable {
    func probedMedia(of file: String) -> ProbedMedia?
    func frameCount(ofImageSequence directory: String) -> Int?
}
