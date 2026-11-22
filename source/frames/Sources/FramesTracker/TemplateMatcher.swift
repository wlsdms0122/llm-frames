//
//  TemplateMatcher.swift
//  FramesTracker
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// Finds where a template best matches a window around it by zero-mean normalised cross-correlation, the standard
// template match that a change of brightness or contrast does not move. The window is the template's size plus
// `reach` pixels on every side, and every offset within `reach` is tried: on the template and window halved
// `levels` times, then around the best offset at each finer level, to a fraction of a pixel at the finest. Only
// pixels inside the picture on both take part, and an offset where fewer than half the template's do is not taken.
struct TemplateMatcher: Sendable {
    // MARK: - Property
    private let reach: Int
    private let levels: Int

    // MARK: - Initializer
    init(
        reach: Int,
        levels: Int
    ) {
        self.reach = reach
        self.levels = levels
    }

    // MARK: - Public
    func match(
        _ template: GreyImage,
        in window: GreyImage
    ) -> TemplateMatch? {
        var templates = [template]
        var windows = [window]
        for _ in 0..<levels {
            templates.append(templates[templates.count - 1].halved())
            windows.append(windows[windows.count - 1].halved())
        }

        var best: (x: Int, y: Int)?
        for level in stride(from: levels, through: 0, by: -1) {
            let levelReach = reach >> level
            let range: [(x: Int, y: Int)]
            if let best {
                range = (-1...1).flatMap { dy in (-1...1).map { dx in (2 * best.x + dx, 2 * best.y + dy) } }
            } else {
                range = (-levelReach...levelReach).flatMap { dy in (-levelReach...levelReach).map { dx in (dx, dy) } }
            }
            let scored = range.compactMap { offset -> (x: Int, y: Int, score: Double)? in
                guard abs(offset.x) <= levelReach, abs(offset.y) <= levelReach else { return nil }
                return correlation(templates[level], windows[level], reach: levelReach, at: offset)
                    .map { (offset.x, offset.y, $0) }
            }
            guard let top = scored.max(by: { $0.score < $1.score }) else { return nil }
            best = (top.x, top.y)
        }
        guard let best else { return nil }

        let reach = self.reach
        let score = { (x: Int, y: Int) in correlation(template, window, reach: reach, at: (x, y)) }
        guard let peak = score(best.x, best.y) else { return nil }
        let x = Double(best.x) + vertex(score(best.x - 1, best.y), peak, score(best.x + 1, best.y))
        let y = Double(best.y) + vertex(score(best.x, best.y - 1), peak, score(best.x, best.y + 1))

        return TemplateMatch(offset: CGPoint(x: x, y: y), correlation: peak)
    }

    // MARK: - Private
    // The correlation of the template with the window's area at `offset` from its centre, over the pixels inside the
    // picture on both.
    private func correlation(
        _ template: GreyImage,
        _ window: GreyImage,
        reach: Int,
        at offset: (x: Int, y: Int)
    ) -> Double? {
        let left = (window.width - template.width) / 2 + offset.x
        let top = (window.height - template.height) / 2 + offset.y
        let rows = max(0, -top)..<min(template.height, window.height - top)
        let columns = max(0, -left)..<min(template.width, window.width - left)
        guard !rows.isEmpty, !columns.isEmpty else { return nil }

        var count = 0.0
        var sum = 0.0
        var otherSum = 0.0
        var product = 0.0
        var square = 0.0
        var otherSquare = 0.0
        template.values.withUnsafeBufferPointer { values in
            window.values.withUnsafeBufferPointer { others in
                for y in rows {
                    let row = y * template.width
                    let otherRow = (top + y) * window.width + left
                    for x in columns {
                        let value = Double(values[row + x])
                        let other = Double(others[otherRow + x])
                        guard !value.isNaN, !other.isNaN else { continue }
                        count += 1
                        sum += value
                        otherSum += other
                        product += value * other
                        square += value * value
                        otherSquare += other * other
                    }
                }
            }
        }
        guard count * 2 >= Double(template.width * template.height) else { return nil }

        let covariance = product - sum * otherSum / count
        let variance = square - sum * sum / count
        let otherVariance = otherSquare - otherSum * otherSum / count
        guard variance > 0, otherVariance > 0 else { return nil }

        return covariance / (variance * otherVariance).squareRoot()
    }

    // The offset, from -0.5 to 0.5, of the top of the parabola through three scores at -1, 0 and 1, the middle one the
    // highest.
    private func vertex(
        _ before: Double?,
        _ peak: Double,
        _ after: Double?
    ) -> Double {
        guard let before, let after else { return 0 }
        let curvature = before - 2 * peak + after
        guard curvature < 0 else { return 0 }

        return min(0.5, max(-0.5, (before - after) / (2 * curvature)))
    }
}
