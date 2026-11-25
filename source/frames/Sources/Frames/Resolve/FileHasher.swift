//
//  FileHasher.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import CryptoKit
import Foundation

// Hashes each file once per resolve: it reads the file in chunks and holds one at a time, so a long video is never
// held in memory, and keeps the digest by path, since media, fonts and frames are named many times in one document.
final class FileHasher: FileHashProvider, @unchecked Sendable {
    // MARK: - Property
    private static let chunkSize = 1 << 20

    private let lock = NSLock()
    private var digests: [String: String] = [:]

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func sha256(ofFile path: String) throws -> String {
        if let digest = lock.withLock({ digests[path] }) {
            return digest
        }

        let digest = try hash(path)
        lock.withLock {
            digests[path] = digest
        }

        return digest
    }

    // MARK: - Public
    // MARK: - Private
    private func hash(_ path: String) throws -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            throw ResolveError.unreadableFile(path: path)
        }
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while true {
            let chunk: Data?
            do {
                // Foundation hands each chunk over through a pool of objects let go of later, which a thread that
                // drains none of its own would keep to its end, so the chunk's pool is drained once it is read.
                chunk = try autoreleasepool { try handle.read(upToCount: Self.chunkSize) }
            } catch {
                throw ResolveError.unreadableFile(path: path)
            }
            guard let chunk, !chunk.isEmpty else { break }

            hasher.update(data: chunk)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
