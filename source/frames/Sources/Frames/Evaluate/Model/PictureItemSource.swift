//
//  PictureItemSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where a picture item's pixels come from: one frame of pinned media, or a nested display list (a compound clip at its
// mapped time, or the list holding a storyline picture's inner item).
package enum PictureItemSource: Equatable, Sendable {
    case media(MediaFrame)
    case displayList(DisplayList)
}
