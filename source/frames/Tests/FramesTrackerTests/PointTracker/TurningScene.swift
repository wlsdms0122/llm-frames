//
//  TurningScene.swift
//  FramesTrackerTests
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import Frames
import FramesTestMedia

// What a turning video shows: a line of black text on white, or a yellow box with a pattern that does not repeat on a
// grey background with marks of its own that stay still.
enum TurningScene: String, Sendable {
    case line
    case patch

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Draws the scene turned and scaled about `centre`, and gives the target as drawn before the turn.
    func draw(
        on canvas: Canvas,
        turned degrees: Double,
        scaled scale: Double,
        about centre: Point
    ) -> Rectangle {
        switch self {
        case .line:
            canvas.fill(red: 255, green: 255, blue: 255)

        case .patch:
            canvas.fill(red: 90, green: 110, blue: 130)
            for column in 0..<16 {
                canvas.fill(Rectangle(x: Double(column) * 40 + 10, y: 310, width: 20, height: 15), red: 60, green: 70, blue: 80)
            }
        }

        var target = Rectangle(x: 0, y: 0, width: 0, height: 0)
        canvas.turned(by: degrees, about: centre) {
            canvas.scaled(by: scale, about: centre) {
                target = drawTarget(on: canvas)
            }
        }

        return target
    }

    // MARK: - Private
    private func drawTarget(on canvas: Canvas) -> Rectangle {
        switch self {
        case .line:
            return canvas.draw("Send the message to everyone", font: "Helvetica", size: 20, x: 212, y: 168)

        case .patch:
            let box = Rectangle(x: 272, y: 156, width: 96, height: 48)
            let bits: UInt32 = 0b1011_0110_0101_1100_1101_0011_1000_1110
            canvas.fill(box, red: 240, green: 200, blue: 40)
            for row in 0..<4 {
                for column in 0..<8 where bits >> UInt32(row * 8 + column) & 1 == 1 {
                    let square = Rectangle(x: box.x + Double(column) * 12, y: box.y + Double(row) * 12, width: 12, height: 12)
                    canvas.fill(square, red: 20, green: 20, blue: 20)
                }
            }
            return box
        }
    }
}
