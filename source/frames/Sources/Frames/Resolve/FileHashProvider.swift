//
//  FileHashProvider.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Gives the SHA-256 of a file a role opens, as 64 lower-case hexadecimal digits, so the resolved document pins it.
protocol FileHashProvider: Sendable {
    func sha256(ofFile path: String) throws -> String
}
