//
//  PageColorRamp.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import Frames

// How the decoder decides whether it converts a colour space of a page by the formulas of FRAMES-26 Media (FRAMES-21
// Rules): it draws a ramp of the space's values with Core Graphics, as it draws the page, each value a square of one
// point painted opaque in Normal blend mode, and compares the linear light it gets with the formula's. A space with no
// formula, and one whose ramp lies further than `tolerance` of linear light from the formula on any channel, are
// refused. Above 1 the tolerance is taken relative to the value, the precision of a float.
struct PageColorRamp {
    // MARK: - Property
    static let tolerance = 1e-4

    private static let columns = 64
    private static let space = CGColorSpace(name: CGColorSpace.extendedSRGB)

    // MARK: - Initializer
    // MARK: - Public
    // The fault of `space`, as `written` writes it in the page, nil where Core Graphics draws it by its formula.
    static func fault(
        of space: PageColorSpace,
        written: PDFValue
    ) throws -> PageFault? {
        if let reason = space.noFormula { return .colorSpace(reason) }
        if case .pattern = space { return nil }

        let values = space.rampValues
        let expected = values.compactMap(space.linear)
        guard expected.count == values.count else {
            return .colorSpace("\(space.name), whose formula gives no colour for some of its values")
        }
        guard let drawn = try drawn(values, in: written) else { return .colorSpace(space.name) }

        let differences = zip(drawn, expected).flatMap { drawn, expected in
            zip([drawn.red, drawn.green, drawn.blue], [expected.red, expected.green, expected.blue])
                .map { drawn, expected in abs(drawn - expected) / max(1, abs(expected)) }
        }
        // A difference that is no number is past the tolerance too.
        let past = differences.filter { !($0 <= tolerance) }
        guard past.isEmpty else {
            let difference = past.filter { !$0.isNaN }.max() ?? .nan
            return .colorSpace(
                "\(space.name), which Core Graphics draws \(String(format: "%.1e", difference)) of linear light from its "
                    + "formula"
            )
        }

        return nil
    }

    // MARK: - Private
    // The linear sRGB Core Graphics draws for each of `values`, nil where a square is not drawn opaque.
    private static func drawn(
        _ values: [[Double]],
        in written: PDFValue
    ) throws -> [RGB]? {
        guard let space else { return nil }
        let rows = (values.count + columns - 1) / columns
        let operators = values.enumerated().map { index, components in
            [
                PDFFileWriter.operation("cs", [.name("S0")]),
                PDFFileWriter.operation("scn", components.map(PDFValue.real)),
                PDFFileWriter.operation("re", [index % columns, index / columns, 1, 1].map(PDFValue.integer)),
                PDFFileWriter.operation("f", [])
            ].joined(separator: " ")
        }.joined(separator: "\n")
        let file = PDFFileWriter.document(pages: [[
            "MediaBox": .array([.integer(0), .integer(0), .integer(columns), .integer(rows)]),
            "Resources": .dictionary(["ColorSpace": .dictionary(["S0": written])]),
            "Contents": PDFFileWriter.content(operators)
        ]])
        guard
            let provider = CGDataProvider(data: file as CFData),
            let page = CGPDFDocument(provider)?.page(at: 1)
        else {
            return nil
        }

        let pixels = try PageRasterizer.pixels(
            of: page,
            width: columns,
            height: rows,
            transform: .identity,
            clip: nil,
            space: space
        )
        let drawn = values.indices.map { index in
            let offset = ((rows - 1 - index / columns) * columns + index % columns) * 4

            return (
                RGB(red: Double(pixels[offset]), green: Double(pixels[offset + 1]), blue: Double(pixels[offset + 2])),
                Double(pixels[offset + 3])
            )
        }
        guard drawn.allSatisfy({ abs($0.1 - 1) < 1e-6 }) else { return nil }

        return drawn.map { TransferFunction.sRGB.decode($0.0) }
    }
}
