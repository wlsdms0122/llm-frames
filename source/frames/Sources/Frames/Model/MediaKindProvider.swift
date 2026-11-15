//
//  MediaKindProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

protocol MediaKindProvider: Sendable {
    func mediaKind(of reference: String) -> MediaKind?
}
