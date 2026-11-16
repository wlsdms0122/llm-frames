//
//  PictureItemSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where a picture item's pixels come from: one frame of pinned media, or a nested display list drawn at its own size
// (an image or layout document, a compound clip at its mapped time, or a storyline unit).
enum PictureItemSource: Equatable, Sendable {
    case media(MediaFrame)
    case displayList(DisplayList)
}
