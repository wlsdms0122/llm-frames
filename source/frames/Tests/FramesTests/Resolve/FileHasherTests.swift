//
//  FileHasherTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import CryptoKit
import Foundation
import Testing

@testable import Frames

@Suite("FileHasher Tests")
struct FileHasherTests {
    // MARK: - Property
    private let sut = FileHasher()
    private let directory: URL

    // MARK: - Initializer
    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frames-hash-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Test
    @Test(
        "a file hashes to its known SHA-256 digest",
        arguments: [
            ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
            ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
            (
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
            ),
            (String(repeating: "a", count: 1_000_000), "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
        ] as [(String, String)]
    )
    func hashesKnownDigest(content: String, expected: String) throws {
        // Given
        let file = try write(Data(content.utf8), named: "known")

        // When
        let digest = try sut.sha256(ofFile: file)

        // Then
        #expect(digest == expected)
    }

    @Test("a file longer than one chunk hashes as a whole")
    func hashesAcrossChunks() throws {
        // Given
        let data = Data((0..<(3 << 20) + 17).map { UInt8(truncatingIfNeeded: $0 * 31) })
        let file = try write(data, named: "long.bin")
        let expected = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        // When
        let digest = try sut.sha256(ofFile: file)

        // Then
        #expect(digest == expected)
    }

    @Test("a path is hashed once within one resolve")
    func cachesByPath() throws {
        // Given
        let file = try write(Data("abc".utf8), named: "cached")
        let first = try sut.sha256(ofFile: file)
        try Data("changed".utf8).write(to: URL(fileURLWithPath: file))

        // When
        let second = try sut.sha256(ofFile: file)

        // Then
        #expect(second == first)
        #expect(try FileHasher().sha256(ofFile: file) != first)
    }

    @Test("a file that cannot be read stops, naming it")
    func stopsOnUnreadableFile() throws {
        // Given
        let file = directory.appendingPathComponent("missing.mp4").path

        // When, Then
        #expect(throws: ResolveError.unreadableFile(path: file)) { try sut.sha256(ofFile: file) }
    }

    // MARK: - Private
    private func write(
        _ data: Data,
        named name: String
    ) throws -> String {
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)

        return url.path
    }
}
