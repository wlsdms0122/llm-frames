//
//  Canvas.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import CoreText
import Foundation
import Frames

// Draws test pictures in media pixels as the picture is displayed, origin at the top left, whatever the context's own
// orientation. Colours are sRGB components from 0 to 255.
package struct Canvas {
    // MARK: - Property
    package let context: CGContext
    package let size: Size

    // MARK: - Initializer
    package init(
        context: CGContext,
        size: Size
    ) {
        self.context = context
        self.size = size
    }

    // MARK: - Public
    package func fill(
        _ rectangle: Rectangle,
        red: Double,
        green: Double,
        blue: Double
    ) {
        context.setFillColor(color(red: red, green: green, blue: blue))
        context.fill(flipped(rectangle))
    }

    package func fill(
        red: Double,
        green: Double,
        blue: Double
    ) {
        fill(Rectangle(x: 0, y: 0, width: size.width, height: size.height), red: red, green: green, blue: blue)
    }

    // Draws one line of `text` whose line box (ascent above the baseline, descent below) starts at `x`, `y`, and
    // gives that box.
    @discardableResult
    package func draw(
        _ text: String,
        font name: String,
        size fontSize: Double,
        x: Double,
        y: Double,
        gray: Double = 0
    ) -> Rectangle {
        let font = CTFontCreateWithName(name as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(red: gray, green: gray, blue: gray)
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)

        context.textPosition = CGPoint(x: x, y: size.height - y - ascent)
        CTLineDraw(line, context)

        return Rectangle(x: x, y: y, width: width, height: ascent + descent)
    }

    // Draws `value` as `bits` squares of `side` pixels from the top left, white for 1 and black for 0, lowest bit
    // first, which a test reads back from decoded pixels.
    package func drawCode(
        _ value: Int,
        bits: Int = 6,
        side: Double = 16
    ) {
        for bit in 0..<bits {
            let level: Double = value >> bit & 1 == 1 ? 255 : 0
            let square = Rectangle(x: Double(bit) * side, y: 0, width: side, height: side)
            fill(square, red: level, green: level, blue: level)
        }
    }

    // Draws what `drawing` draws turned `degrees` clockwise, as the picture is displayed, about `centre`.
    package func turned(
        by degrees: Double,
        about centre: Point,
        drawing: () -> Void
    ) {
        context.saveGState()
        defer { context.restoreGState() }

        // The context's y axis points up, so a clockwise turn on the displayed picture is a negative angle in it.
        context.translateBy(x: centre.x, y: size.height - centre.y)
        context.rotate(by: -degrees * .pi / 180)
        context.translateBy(x: -centre.x, y: -(size.height - centre.y))
        drawing()
    }

    // Draws what `drawing` draws scaled by `scale` about `centre`.
    package func scaled(
        by scale: Double,
        about centre: Point,
        drawing: () -> Void
    ) {
        context.saveGState()
        defer { context.restoreGState() }

        context.translateBy(x: centre.x, y: size.height - centre.y)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -centre.x, y: -(size.height - centre.y))
        drawing()
    }

    // MARK: - Private
    private func flipped(_ rectangle: Rectangle) -> CGRect {
        CGRect(
            x: rectangle.x,
            y: size.height - rectangle.y - rectangle.height,
            width: rectangle.width,
            height: rectangle.height
        )
    }

    private func color(
        red: Double,
        green: Double,
        blue: Double
    ) -> CGColor {
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [red / 255, green / 255, blue / 255, 1]
        )!
    }
}
