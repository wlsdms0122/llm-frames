//
//  ResolvedText+Static.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

// Text as resolve gives a title no keyframe moves: its background held, its text box its box less the background's
// padding, wrapping at its text box's width, without text, lines or a line height.
extension ResolvedText {
    // MARK: - Property
    // MARK: - Initializer
    init(
        size: Size,
        background: TextBackground?,
        runs: [ResolvedGlyphRun]
    ) {
        let padding = background?.padding ?? Size(width: 0, height: 0)

        self.init(
            size: size,
            textBox: Rectangle(
                x: padding.width,
                y: padding.height,
                width: size.width - padding.width * 2,
                height: size.height - padding.height * 2
            ),
            width: size.width - padding.width * 2,
            background: background.map { background in
                ResolvedBackground(
                    color: .held(.color(background.color)),
                    padding: .held(.numbers([background.padding.height, background.padding.width])),
                    radius: .held(.number(background.radius))
                )
            },
            align: .left,
            lineHeight: .off,
            text: "",
            words: [],
            lines: [],
            units: nil,
            runs: runs
        )
    }

    // MARK: - Public
    // MARK: - Private
}
