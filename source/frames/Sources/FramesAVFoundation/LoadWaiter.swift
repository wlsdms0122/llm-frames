//
//  LoadWaiter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import Foundation
import os

// Waits for AVFoundation's loads of `file`, since the decoder is called synchronously, as resolve runs. It uses the
// loads that call back on AVFoundation's own queues: an awaited load resumes on Swift's shared pool, which callers
// blocked on that pool can leave without a thread.
struct LoadWaiter: Sendable {
    // MARK: - Property
    private let file: String

    // MARK: - Initializer
    init(file: String) {
        self.file = file
    }

    // MARK: - Public
    func tracks(
        of asset: AVAsset,
        type: AVMediaType
    ) throws -> [AVAssetTrack] {
        let semaphore = DispatchSemaphore(value: 0)
        let result = OSAllocatedUnfairLock<Result<[AVAssetTrack], any Error>?>(uncheckedState: nil)
        asset.loadTracks(withMediaType: type) { [file] tracks, error in
            let outcome: Result<[AVAssetTrack], any Error> = tracks.map { .success($0) }
                ?? .failure(error ?? DecoderError.unreadable(file: file))
            result.withLockUnchecked { $0 = outcome }
            semaphore.signal()
        }
        semaphore.wait()

        return try result.withLockUnchecked { $0! }.get()
    }

    // The value of `property`, loaded by its `key`. The only load of a key that calls back is deprecated for Swift in
    // favour of the awaited one.
    @diagnose(DeprecatedDeclaration, as: ignored)
    func value<Object: AVAsynchronousKeyValueLoading, Value>(
        of property: AVAsyncProperty<Object, Value>,
        key: String,
        in object: Object
    ) throws -> Value {
        let semaphore = DispatchSemaphore(value: 0)
        object.loadValuesAsynchronously(forKeys: [key]) { semaphore.signal() }
        semaphore.wait()

        switch object.status(of: property) {
        case let .loaded(value):
            return value

        case let .failed(error):
            throw error

        default:
            throw DecoderError.unreadable(file: file)
        }
    }

    // MARK: - Private
}
