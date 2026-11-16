//
//  ImageOperationKind.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What an image operation is, named by the one key that makes it so.
enum ImageOperationKind: String, CaseIterable, Equatable, Sendable {
    case crop
    case resize
    case pad
    case shape
    case adjust
    case title
    case banner
    case border
}
