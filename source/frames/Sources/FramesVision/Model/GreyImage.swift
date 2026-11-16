//
//  GreyImage.swift
//  FramesVision
//
//  Created by JSilver on 11/16/26.
//

// Grey values from 0 to 1, row by row from the top left. A pixel outside the picture it was read from is NaN and
// takes no part in a comparison.
struct GreyImage: Sendable {
    // MARK: - Property
    let width: Int
    let height: Int
    let values: [Float]

    // MARK: - Initializer
    init(
        width: Int,
        height: Int,
        values: [Float]
    ) {
        self.width = width
        self.height = height
        self.values = values
    }

    // MARK: - Public
    func value(
        x: Int,
        y: Int
    ) -> Float {
        values[y * width + x]
    }

    // Half the size, each pixel the mean of the two by two it covers that lie inside the picture.
    func halved() -> GreyImage {
        let halfWidth = max(1, width / 2)
        let halfHeight = max(1, height / 2)
        var halved = [Float](repeating: .nan, count: halfWidth * halfHeight)
        values.withUnsafeBufferPointer { values in
            for y in 0..<halfHeight {
                for x in 0..<halfWidth {
                    var sum: Float = 0
                    var count: Float = 0
                    for row in (2 * y)..<min(2 * y + 2, height) {
                        for column in (2 * x)..<min(2 * x + 2, width) {
                            let value = values[row * width + column]
                            guard !value.isNaN else { continue }
                            sum += value
                            count += 1
                        }
                    }
                    if count > 0 { halved[y * halfWidth + x] = sum / count }
                }
            }
        }

        return GreyImage(width: halfWidth, height: halfHeight, values: halved)
    }

    // MARK: - Private
}
