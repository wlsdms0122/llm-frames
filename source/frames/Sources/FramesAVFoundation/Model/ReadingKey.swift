//
//  ReadingKey.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

import Frames

// A medium and the conversion its pictures are read by: its pinned path, the directory of an image sequence, and its
// page, nil for a medium that is no page of a PDF.
struct ReadingKey: Hashable, Sendable {
    // MARK: - Property
    let path: String
    let page: Int?
    let conversion: WorkingConversion

    // MARK: - Initializer
    init(
        path: String,
        page: Int?,
        conversion: WorkingConversion
    ) {
        self.path = path
        self.page = page
        self.conversion = conversion
    }

    // MARK: - Public
    // MARK: - Private
}
