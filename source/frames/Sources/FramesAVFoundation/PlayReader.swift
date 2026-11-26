//
//  PlayReader.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/26/26.
//

import AVFoundation
import Foundation
import Frames
import os

// The reader of one play of a video, the place that play has reached (FRAMES-21 Rules). One reader stays open after
// the last frame the play read, until it is closed, so the play's frames in order decode forward from it instead of
// from the previous sync sample each time, and a frame of another play of the video never moves it. The buffers a turn
// holds for later asks are the run's budget's `turns`, each held only where the budget grants it (FRAMES-30 The
// budget), until the play asks it or ends.
final class PlayReader: Sendable {
    // MARK: - Property
    // A later frame further ahead than this, in seconds, restarts the reader at it rather than decoding up to it.
    private static let forwardReach: Double = 1

    private let video: VideoReader
    private let budget: MemoryBudget
    private let state = OSAllocatedUnfairLock<ReadState>(uncheckedState: ReadState())
    // The frames whose buffers `state` holds, read without its lock while a frame is being read.
    private let heldFrames = OSAllocatedUnfairLock<Set<Int>>(initialState: [])

    // Whether the buffer of a frame a reader read past the frame it was opened for is held.
    var holdsFrames: Bool {
        !heldFrames.withLock(\.isEmpty)
    }

    // MARK: - Initializer
    // `budget` is the run's, which the buffers a turn holds draw from.
    init(
        video: VideoReader,
        budget: MemoryBudget = MemoryBudget(limit: .unlimited)
    ) {
        self.video = video
        self.budget = budget
    }

    // MARK: - Public
    // Whether the buffer of frame `index` is held.
    func holds(frame index: Int) -> Bool {
        heldFrames.withLock { $0.contains(index) }
    }

    // The frames a reader opened for frame `index` in a turn of `turn` frames would hold, asked next.
    func turnHolds(
        atFrame index: Int,
        turn: Int
    ) -> Int {
        state.withLockUnchecked { following(index, step: step(to: index, from: $0.asked), turn: turn).count }
    }

    // The buffer of frame `index` as the file stores it, in the video's `decodedFormat`, the samples decoded to reach
    // it, and whether a reader was opened again for it, which the first reader opened for the play is not. A reader
    // opened for it reads `turn` frames, frame `index` and the frames after it by the step from the frame the play
    // asked before, within `forwardReach` of it, and holds the buffers of the others, which later asks give with no
    // reader, as many as the budget grants room for: `room` is bytes the budget granted its `turns` for them, which
    // they hold first, and what they do not hold of it is given back. Every buffer held of a frame up to `index` is let
    // go of. A reader is opened only where `isAdmitted` holds, asked under the lock `close()` takes, so a close that
    // follows the admission it asks about closes the reader it opens. Nil where the frame needs a reader opened and
    // `isAdmitted` does not hold: nothing is read and nothing is let go of.
    func buffer(
        atFrame index: Int,
        path: String,
        turn: Int,
        room: Int,
        isAdmitted: () -> Bool
    ) throws -> (buffer: CVImageBuffer, decoded: Int, reopened: Bool)? {
        var room = room
        defer { budget.give(room, for: .turns) }
        let frames = video.frames
        let time = frames[index]
        let read = try state.withLockUnchecked { state -> (CVImageBuffer?, Int, Bool)? in
            let readsOn = state.reader.map {
                $0.index == index || $0.index < index && (time - $0.time).seconds <= Self.forwardReach
            } ?? false
            guard readsOn || state.held.contains(where: { $0.index == index }) || isAdmitted() else { return nil }

            let step = self.step(to: index, from: state.asked)
            state.asked = index
            let held = state.held.first { $0.index == index }
            letGo(of: state.held.filter { $0.index <= index })
            state.held.removeAll { $0.index <= index }
            defer { heldFrames.withLock { [kept = Set(state.held.map(\.index))] in $0 = kept } }
            if let held { return (held.buffer, 0, false) }
            if let reader = state.reader, reader.index == index { return (reader.picture, 0, false) }
            if let reader = state.reader, reader.index < index, (time - reader.time).seconds <= Self.forwardReach {
                let before = reader.decoded
                let picture = try reader.read(frame: index, at: time, path: path)

                return (picture, reader.decoded - before, false)
            }

            let reopened = state.hasOpened
            let reader = try video.frameReader(at: time, path: path)
            state.reader = reader
            state.hasOpened = true
            let picture = try reader.read(frame: index, at: time, path: path)
            letGo(of: state.held)
            state.held = []
            for next in following(index, step: step, turn: turn) {
                guard let buffer = try reader.read(frame: next, at: frames[next], path: path) else { break }
                let bytes = CVPixelBufferGetDataSize(buffer)
                let granted = min(bytes, room)
                guard granted == bytes || budget.take(bytes - granted, for: .turns) else { break }
                room -= granted
                state.held.append((next, buffer))
            }

            return (picture, reader.decoded, reopened)
        }
        guard let (shown, decoded, reopened) = read else { return nil }
        guard let shown else { throw DecoderError.noFrame(file: path, index: index, count: frames.count) }

        return (shown, decoded, reopened)
    }

    // Lets go of the reader open for the play, so the play's next frame read opens one at that frame, and keeps the
    // buffers held. A read in progress ends first.
    func close() {
        state.withLockUnchecked { $0.reader = nil }
    }

    // Ends the play: lets go of the reader open for it and of the buffers held for it, whose bytes it gives back to the
    // budget's `turns` (FRAMES-21 Rules). A read in progress ends first.
    func end() {
        state.withLockUnchecked { state in
            state.reader = nil
            letGo(of: state.held)
            state.held = []
            heldFrames.withLock { $0 = [] }
        }
    }

    // MARK: - Private
    // The step from frame `asked`, the frame the play asked before, to frame `index`, 1 where there is none or it is
    // not forward.
    private func step(
        to index: Int,
        from asked: Int?
    ) -> Int {
        asked.map { index - $0 }.flatMap { $0 > 0 ? $0 : nil } ?? 1
    }

    // The frames after frame `index` by `step` that a reader opened for it in a turn of `turn` frames reads past it,
    // within `forwardReach` of it.
    private func following(
        _ index: Int,
        step: Int,
        turn: Int
    ) -> [Int] {
        let frames = video.frames

        return Array(stride(from: index + step, to: frames.count, by: step).prefix(turn - 1).prefix {
            (frames[$0] - frames[index]).seconds <= Self.forwardReach
        })
    }

    private func letGo(of held: [(index: Int, buffer: CVImageBuffer)]) {
        budget.give(held.reduce(0) { $0 + CVPixelBufferGetDataSize($1.buffer) }, for: .turns)
    }
}

extension PlayReader {
    // The reader open for the play, none before its first frame is read and after it is closed, the frame the play
    // asked last, the buffers of the frames the last reader opened read past the frame it was opened for, and whether
    // a reader was ever opened for the play.
    private struct ReadState {
        var reader: FrameReader?
        var asked: Int?
        var held: [(index: Int, buffer: CVImageBuffer)] = []
        var hasOpened = false
    }
}
