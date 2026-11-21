//
//  AccumulationBuffer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/21/26.
//

import Dispatch
import Frames

// The sum of the pictures of a frame's sample lists and their mean, as FRAMES-29 gives it: each premultiplied component
// summed in 32-bit float from 0 in the order the pictures are added, then divided once by their number and rounded to
// the nearest half float. A picture is added as soon as it is drawn, so only the sum outlives it. Rows are summed in
// parallel, and each component's additions keep their order.
final class AccumulationBuffer {
    // MARK: - Property
    let width: Int
    let height: Int

    private var sums: [Float]
    private var count = 0

    // MARK: - Initializer
    init(
        width: Int,
        height: Int
    ) {
        self.width = width
        self.height = height
        self.sums = [Float](repeating: 0, count: width * height * 4)
    }

    // MARK: - Public
    // Adds a picture of the buffer's size.
    func add(_ frame: FrameContext) {
        precondition(frame.width == width && frame.height == height, "a picture of another size than the sum")

        let rowLength = width * 4
        let bytesPerRow = frame.context.bytesPerRow
        nonisolated(unsafe) let pixels = UnsafeRawPointer(frame.context.data!)
        sums.withUnsafeMutableBufferPointer { buffer in
            nonisolated(unsafe) let sums = buffer.baseAddress!
            DispatchQueue.concurrentPerform(iterations: height) { row in
                let halves = (pixels + row * bytesPerRow).assumingMemoryBound(to: Float16.self)
                let sum = sums + row * rowLength
                for index in 0..<rowLength {
                    sum[index] += Float(halves[index])
                }
            }
        }
        count += 1
    }

    // The mean of the pictures added, on a frame in the form `compositing` names, the form they were drawn in.
    func mean(compositing: Compositing) throws -> FrameContext {
        let frame = try FrameContext(width: width, height: height, compositing: compositing)
        let rowLength = width * 4
        let bytesPerRow = frame.context.bytesPerRow
        let divisor = Float(count)
        nonisolated(unsafe) let pixels = frame.context.data!
        sums.withUnsafeBufferPointer { buffer in
            nonisolated(unsafe) let sums = buffer.baseAddress!
            DispatchQueue.concurrentPerform(iterations: height) { row in
                let halves = (pixels + row * bytesPerRow).assumingMemoryBound(to: Float16.self)
                let sum = sums + row * rowLength
                for index in 0..<rowLength {
                    halves[index] = Float16(sum[index] / divisor)
                }
            }
        }

        return frame
    }

    // MARK: - Private
}
