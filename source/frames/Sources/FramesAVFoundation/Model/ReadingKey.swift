//
//  ReadingKey.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

import Frames

// A medium, the conversion its pictures are read by and the processor that ran it: its pinned path, the directory of an image sequence, and its
// page, nil for a medium that is no page of a PDF.
struct ReadingKey: Hashable, Sendable {
    // MARK: - Property
    let path: String
    let page: Int?
    let conversion: WorkingConversion
    let device: ConversionDevice

    // MARK: - Initializer
    init(
        path: String,
        page: Int?,
        conversion: WorkingConversion,
        device: ConversionDevice
    ) {
        self.path = path
        self.page = page
        self.conversion = conversion
        self.device = device
    }

    // MARK: - Public
    // MARK: - Private
}
