//
//  PictureDocument.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A document that draws one picture.
indirect enum PictureDocument: Equatable, Sendable {
    case image(ImageDocument)
    case layout(LayoutDocument)
}
