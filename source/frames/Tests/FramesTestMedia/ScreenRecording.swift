//
//  ScreenRecording.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation
import Frames

// A portrait screen recording at 30 frames a second for one second, 720 by 1280 at scale 1, stored turned, whose line
// "Total 12,000원" scrolls up 4 pixels a frame at scale 1 under a still line "Send message".
package struct ScreenRecording {
    // MARK: - Property
    package static let frameTimes = (0..<30).map { Double($0) / 30 }

    private let scale: Double

    package var size: Size {
        Size(width: 720 * scale, height: 1280 * scale)
    }

    // MARK: - Initializer
    package init(scale: Double = 1) {
        self.scale = scale
    }

    // MARK: - Public
    // Writes the recording and gives the drawn line box of the scrolling line on each frame, in display pixels.
    package func write(to path: String) async throws -> [Rectangle] {
        let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: size.width, ty: 0)
        let writer = MovieWriter(
            size: Size(width: size.height, height: size.width),
            frameTimes: Self.frameTimes,
            end: 1,
            transform: quarterTurn
        )
        var drawn: [Rectangle] = []
        try await writer.write(to: path) { canvas, index in
            canvas.fill(red: 255, green: 255, blue: 255)
            canvas.draw("Send message", font: "Helvetica", size: 48 * scale, x: 60 * scale, y: 200 * scale)
            drawn.append(canvas.draw(
                "Total 12,000원",
                font: "AppleSDGothicNeo-Bold",
                size: 48 * scale,
                x: 100 * scale,
                y: (700 - 4 * Double(index)) * scale
            ))
        }

        return drawn
    }

    // MARK: - Private
}
