//
//  VideoWriter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Writes the frames of one video file in order.
package protocol VideoWriter {
    // The k-th frame appended is presented at k / fps.
    func append(_ frame: Bitmap) throws

    // Writes the rest of the file and closes it. Nothing is appended after.
    func finish() throws
}
