//
//  PDFFileWriter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// Writes a PDF file (ISO 32000-1 7.5) of indirect objects with a cross-reference table, unencrypted and uncompressed.
// A stream nested in another object is written as an object of its own, since a stream is always indirect.
struct PDFFileWriter {
    // MARK: - Property
    private var objects: [PDFValue] = []

    // MARK: - Initializer
    init() {}

    // MARK: - Public
    // A file whose catalog holds `catalog` and a page tree of `pages`, each a page dictionary without `Type` and
    // `Parent`, which are added.
    static func document(
        pages: [[String: PDFValue]],
        catalog: [String: PDFValue] = [:],
        writer: PDFFileWriter = PDFFileWriter()
    ) -> Data {
        var writer = writer
        let tree = writer.reserve()
        let kids = pages.map { page in
            writer.add(.dictionary(page.merging(["Type": .name("Page"), "Parent": tree]) { _, added in added }))
        }
        writer.set(tree, to: .dictionary(["Type": .name("Pages"), "Kids": .array(kids), "Count": .integer(kids.count)]))
        let root = writer.add(.dictionary(catalog.merging(["Type": .name("Catalog"), "Pages": tree]) { _, added in added }))

        return writer.data(root: root)
    }

    // A content stream of `operators`.
    static func content(_ operators: String) -> PDFValue {
        .stream([:], Data(operators.utf8))
    }

    // The reference to `value` as a new object.
    mutating func add(_ value: PDFValue) -> PDFValue {
        objects.append(value)

        return .reference(objects.count)
    }

    // The reference to an object set later.
    mutating func reserve() -> PDFValue {
        add(.null)
    }

    mutating func set(
        _ reference: PDFValue,
        to value: PDFValue
    ) {
        guard case let .reference(number) = reference else { return }

        objects[number - 1] = value
    }

    func data(root: PDFValue) -> Data {
        var hoisted = objects
        var index = 0
        while index < hoisted.count {
            hoisted[index] = Self.hoisting(hoisted[index], into: &hoisted, isTop: true)
            index += 1
        }

        var file = Data("%PDF-1.7\n".utf8)
        var offsets: [Int] = []
        for (index, object) in hoisted.enumerated() {
            offsets.append(file.count)
            file.append(Data("\(index + 1) 0 obj\n".utf8))
            file.append(Self.written(object))
            file.append(Data("\nendobj\n".utf8))
        }

        let crossReference = file.count
        var table = "xref\n0 \(hoisted.count + 1)\n0000000000 65535 f \n"
        for offset in offsets {
            table += String(format: "%010d 00000 n \n", offset)
        }
        let trailer = Self.written(.dictionary(["Size": .integer(hoisted.count + 1), "Root": root]))
        table += "trailer\n\(String(decoding: trailer, as: UTF8.self))\nstartxref\n\(crossReference)\n%%EOF\n"
        file.append(Data(table.utf8))

        return file
    }

    // MARK: - Private
    // `value` with each stream below the top replaced by a reference to a new object.
    private static func hoisting(
        _ value: PDFValue,
        into objects: inout [PDFValue],
        isTop: Bool
    ) -> PDFValue {
        switch value {
        case let .array(elements):
            return .array(elements.map { hoisting($0, into: &objects, isTop: false) })

        case let .dictionary(entries):
            return .dictionary(entries.mapValues { hoisting($0, into: &objects, isTop: false) })

        case let .stream(entries, data):
            let stream = PDFValue.stream(entries.mapValues { hoisting($0, into: &objects, isTop: false) }, data)
            guard !isTop else { return stream }
            objects.append(stream)

            return .reference(objects.count)

        default:
            return value
        }
    }

    private static func written(_ value: PDFValue) -> Data {
        switch value {
        case .null:
            return Data("null".utf8)

        case let .boolean(value):
            return Data((value ? "true" : "false").utf8)

        case let .integer(value):
            return Data("\(value)".utf8)

        case let .real(value):
            return Data(String(format: "%.10f", value).utf8)

        case let .name(name):
            return Data("/\(escaped(name))".utf8)

        case let .string(bytes):
            return Data("<\(bytes.map { String(format: "%02x", $0) }.joined())>".utf8)

        case let .array(elements):
            var data = Data("[".utf8)
            for element in elements {
                data.append(written(element))
                data.append(Data(" ".utf8))
            }
            data.append(Data("]".utf8))

            return data

        case let .dictionary(entries):
            return writtenDictionary(entries)

        case let .stream(entries, bytes):
            var data = writtenDictionary(entries.merging(["Length": .integer(bytes.count)]) { _, length in length })
            data.append(Data("\nstream\n".utf8))
            data.append(bytes)
            data.append(Data("\nendstream".utf8))

            return data

        case let .reference(number):
            return Data("\(number) 0 R".utf8)
        }
    }

    // A name's bytes outside the regular characters written as #xx (ISO 32000-1 7.3.5).
    private static func escaped(_ name: String) -> String {
        let delimiters = Set("()<>[]{}/%#".utf8)

        return name.utf8.map { byte in
            (0x21...0x7E).contains(byte) && !delimiters.contains(byte)
                ? String(UnicodeScalar(byte))
                : String(format: "#%02X", byte)
        }.joined()
    }

    private static func writtenDictionary(_ entries: [String: PDFValue]) -> Data {
        var data = Data("<<".utf8)
        for key in entries.keys.sorted() {
            data.append(Data(" /\(escaped(key)) ".utf8))
            data.append(written(entries[key] ?? .null))
        }
        data.append(Data(" >>".utf8))

        return data
    }
}
