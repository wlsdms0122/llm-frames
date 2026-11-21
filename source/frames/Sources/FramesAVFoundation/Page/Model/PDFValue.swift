//
//  PDFValue.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation

// A PDF object (ISO 32000-1 7.3) copied out of a document, its references resolved: what the decoder reads of a colour
// space and its functions and profiles, and writes again into the pages it draws a colour space's ramp on. A stream
// holds its dictionary and its decoded data, so its filter keys no longer apply. `reference` names an object of a file
// being written by `PDFFileWriter`, and no copied value holds one.
indirect enum PDFValue: Hashable, Sendable {
    case null
    case boolean(Bool)
    case integer(Int)
    case real(Double)
    case name(String)
    case string(Data)
    case array([PDFValue])
    case dictionary([String: PDFValue])
    case stream([String: PDFValue], Data)
    case reference(Int)

    // MARK: - Property
    // How deep a copy follows nested objects: a colour space nests a few levels, and a deeper object is no colour.
    private static let depthLimit = 12

    var number: Double? {
        switch self {
        case let .integer(value):
            Double(value)

        case let .real(value):
            value.isFinite ? value : nil

        default:
            nil
        }
    }

    var nameValue: String? {
        guard case let .name(name) = self else { return nil }

        return name
    }

    var arrayValue: [PDFValue]? {
        guard case let .array(values) = self else { return nil }

        return values
    }

    // A dictionary's entries, or a stream's dictionary.
    var dictionaryValue: [String: PDFValue]? {
        switch self {
        case let .dictionary(entries), let .stream(entries, _):
            entries

        default:
            nil
        }
    }

    var numbers: [Double]? {
        guard let values = arrayValue else { return nil }
        let numbers = values.compactMap(\.number)

        return numbers.count == values.count ? numbers : nil
    }

    // MARK: - Initializer
    init(_ object: CGPDFObjectRef) {
        self.init(object, depth: 0)
    }

    init(_ dictionary: CGPDFDictionaryRef) {
        self = .dictionary(Self.entries(of: dictionary, depth: 0))
    }

    init(_ stream: CGPDFStreamRef) {
        self = Self.copied(stream, depth: 0)
    }

    private init(
        _ object: CGPDFObjectRef,
        depth: Int
    ) {
        guard depth < Self.depthLimit else {
            self = .null
            return
        }

        switch CGPDFObjectGetType(object) {
        case .boolean:
            var value: CGPDFBoolean = 0
            CGPDFObjectGetValue(object, .boolean, &value)
            self = .boolean(value != 0)

        case .integer:
            var value: CGPDFInteger = 0
            CGPDFObjectGetValue(object, .integer, &value)
            self = .integer(value)

        case .real:
            var value: CGPDFReal = 0
            CGPDFObjectGetValue(object, .real, &value)
            self = .real(Double(value))

        case .name:
            var name: UnsafePointer<CChar>?
            CGPDFObjectGetValue(object, .name, &name)
            self = name.map { .name(String(cString: $0)) } ?? .null

        case .string:
            var string: CGPDFStringRef?
            CGPDFObjectGetValue(object, .string, &string)
            self = string.flatMap { string in
                CGPDFStringGetBytePtr(string).map { .string(Data(bytes: $0, count: CGPDFStringGetLength(string))) }
            } ?? .null

        case .array:
            var array: CGPDFArrayRef?
            CGPDFObjectGetValue(object, .array, &array)
            self = array.map { array in
                .array((0..<CGPDFArrayGetCount(array)).map { index in
                    var element: CGPDFObjectRef?
                    guard CGPDFArrayGetObject(array, index, &element), let element else { return .null }

                    return PDFValue(element, depth: depth + 1)
                })
            } ?? .null

        case .dictionary:
            var dictionary: CGPDFDictionaryRef?
            CGPDFObjectGetValue(object, .dictionary, &dictionary)
            self = dictionary.map { .dictionary(Self.entries(of: $0, depth: depth + 1)) } ?? .null

        case .stream:
            var stream: CGPDFStreamRef?
            CGPDFObjectGetValue(object, .stream, &stream)
            self = stream.map { Self.copied($0, depth: depth + 1) } ?? .null

        default:
            self = .null
        }
    }

    // MARK: - Public
    subscript(key: String) -> PDFValue? {
        dictionaryValue?[key]
    }

    // The whole number in `range` this value writes, nil for anything else: no number, a fraction, or a number past
    // `range`. Every number the decoder reads as a count, an index or a kind is read here, and the caller refuses nil.
    func integer(in range: ClosedRange<Int>) -> Int? {
        guard let number, let whole = Int(exactly: number), range.contains(whole) else { return nil }

        return whole
    }

    // MARK: - Private
    private static func entries(
        of dictionary: CGPDFDictionaryRef,
        depth: Int
    ) -> [String: PDFValue] {
        var collected: [(String, CGPDFObjectRef)] = []
        CGPDFDictionaryApplyBlock(dictionary, { key, object, _ in
            collected.append((String(cString: key), object))

            return true
        }, nil)

        // A page or a parent reaches the page tree, which no colour space holds.
        return Dictionary(
            collected
                .filter { !["Parent", "P"].contains($0.0) }
                .map { ($0.0, PDFValue($0.1, depth: depth)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func copied(
        _ stream: CGPDFStreamRef,
        depth: Int
    ) -> PDFValue {
        let entries = CGPDFStreamGetDictionary(stream).map { entries(of: $0, depth: depth) } ?? [:]
        var format = CGPDFDataFormat.raw
        let data = CGPDFStreamCopyData(stream, &format).map { $0 as Data } ?? Data()

        return .stream(entries.filter { !["Filter", "DecodeParms", "Length", "DL"].contains($0.key) }, data)
    }
}
