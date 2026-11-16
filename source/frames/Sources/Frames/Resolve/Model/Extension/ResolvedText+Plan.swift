//
//  ResolvedText+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Text as set, with the font file of each run pinned.
extension ResolvedText {
    // MARK: - Property
    // MARK: - Initializer
    init(
        layout: TextLayout,
        hashes: any FileHashProvider
    ) throws {
        self.init(
            size: layout.size,
            lineCount: layout.lineCount,
            background: layout.background,
            stroke: layout.stroke,
            runs: try layout.runs.map { run in
                ResolvedGlyphRun(
                    font: try PinnedFile(path: run.face.file, hashes: hashes),
                    face: run.face.name,
                    size: run.size,
                    color: run.color,
                    glyphs: run.glyphs
                )
            }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
