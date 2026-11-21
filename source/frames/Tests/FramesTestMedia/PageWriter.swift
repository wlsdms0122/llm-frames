//
//  PageWriter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// Writes a PDF of one page of `width` by `height` points whose content stream is `content`, in the page's own
// coordinates, y pointing up from the bottom left, in DeviceGray or DeviceRGB.
package struct PageWriter {
    // MARK: - Property
    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func write(
        width: Double,
        height: Double,
        content: String,
        to path: String
    ) throws {
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 \(width) \(height)] /Resources << >> /Contents 4 0 R >>",
            "<< /Length \(content.utf8.count) >>\nstream\n\(content)\nendstream"
        ]
        var text = "%PDF-1.4\n"
        var offsets: [Int] = []
        for (index, object) in objects.enumerated() {
            offsets.append(text.utf8.count)
            text += "\(index + 1) 0 obj\n\(object)\nendobj\n"
        }
        let table = text.utf8.count
        text += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
        text += offsets.map { String(format: "%010d 00000 n \n", $0) }.joined()
        text += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(table)\n%%EOF\n"

        try Data(text.utf8).write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Private
}
