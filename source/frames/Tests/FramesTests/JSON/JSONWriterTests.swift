//
//  JSONWriterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("JSONWriter Tests")
struct JSONWriterTests {
    // MARK: - Property
    private let sut = JSONWriter()
    private let reader = JSONReader()

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a number is written in its shortest decimal form, with no exponent",
        arguments: [
            (0.0, "0"),
            (-0.0, "0"),
            (1080, "1080"),
            (-1080, "-1080"),
            (0.1, "0.1"),
            (13.95, "13.95"),
            (1.0 / 3, "0.3333333333333333"),
            (2.0 / 3, "0.6666666666666666"),
            (0.1 + 0.2, "0.30000000000000004"),
            (1e-7, "0.0000001"),
            (-2.5e-5, "-0.000025"),
            (0.0001, "0.0001"),
            (29.97, "29.97"),
            (30000.0 / 1001, "29.97002997002997"),
            (1e15, "1000000000000000"),
            (1e16, "10000000000000000"),
            (1.5e20, "150000000000000000000"),
            (9007199254740992, "9007199254740992"),
            (123456789012345680, "123456789012345680"),
            (1206.5, "1206.5"),
            (-0.5, "-0.5")
        ] as [(Double, String)]
    )
    func writesNumber(number: Double, expected: String) throws {
        // Given
        let value = JSONValue.number(number)

        // When
        let text = sut.number(number)

        // Then
        #expect(text == expected)
        #expect(try reader.read(sut.write(value)) == value)
    }

    @Test(
        "every number reads back to the same double",
        arguments: [
            0.1, 0.2, 0.7, 1.1, 2.675, 13.95, 92.1, 1.0 / 3, 1.0 / 7, 1e-7, 1.234e-9, 5e-324, 2.2250738585072014e-308,
            .pi, 2.0.squareRoot(), 1e21, 1.7976931348623157e308, 4503599627370497, 0.000001, 1.0 / 29.97, 12.95,
            51.4, 70.9, 0.0333, 0.0667, 1e300, -1e-300
        ] as [Double]
    )
    func readsNumberBack(number: Double) throws {
        // Given
        let value = JSONValue.number(number)

        // When
        let text = sut.write(value)

        // Then
        #expect(try reader.read(text) == value)
        #expect(!text.contains("e") && !text.contains("E"))
    }

    @Test("numbers made by arithmetic read back the same")
    func readsComputedNumbersBack() throws {
        // Given
        let numbers = (0..<1000).map { Double($0) / 29.97 } + (1..<500).map { 1 / Double($0) }

        // When
        let text = sut.write(.array(numbers.map { .number($0) }))

        // Then
        #expect(try reader.read(text) == .array(numbers.map { .number($0) }))
    }

    @Test(
        "a string escapes quotes, backslashes and control characters",
        arguments: [
            ("plain", #""plain""#),
            ("say \"hi\"", #""say \"hi\"""#),
            (#"C:\path"#, #""C:\\path""#),
            ("a/b", #""a/b""#),
            ("line\nnext\ttab\rback", #""line\nnext\ttab\rback""#),
            ("\u{08}\u{0C}", #""\b\f""#),
            ("\u{00}\u{1F}", #""\u0000\u001F""#),
            ("\u{7F}", "\"\u{7F}\"")
        ]
    )
    func escapesString(string: String, expected: String) throws {
        // Given
        let value = JSONValue.string(string)

        // When
        let text = sut.string(string)

        // Then
        #expect(text == expected)
        #expect(try reader.read(text) == value)
    }

    @Test("Korean text, emoji and other characters are written as themselves")
    func writesUnicodeAsItself() throws {
        // Given
        let string = "누수 잡기 😀 e\u{301} \u{2028}"

        // When
        let text = sut.string(string)

        // Then
        #expect(text == "\"\(string)\"")
        #expect(try reader.read(text) == .string(string))
        #expect(Data(sut.write(.string(string)).utf8) == Data("\"\(string)\"\n".utf8))
    }

    @Test("members keep the order the object holds them in")
    func keepsMemberOrder() throws {
        // Given
        let value = JSONValue.object(JSONObject(members: [
            JSONMember(key: "z", value: .number(1)),
            JSONMember(key: "a", value: .number(2)),
            JSONMember(key: "m", value: .number(3))
        ]))

        // When
        let text = sut.write(value)

        // Then
        #expect(text == "{\n  \"z\": 1,\n  \"a\": 2,\n  \"m\": 3\n}\n")
        #expect(try reader.read(text).objectValue?.keys == ["z", "a", "m"])
    }

    @Test("a list of plain values stays on one line, and nested values are indented")
    func indentsNestedValues() throws {
        // Given
        let value = try reader.read(#"""
            { "size": [1080, 1920], "empty": [], "none": {}, "glyphs": [[1043, 21.4, 52], [3, 288.1, 52]],
              "runs": [{ "font": "/a.ttc", "on": true, "stroke": null }] }
            """#)

        // When
        let text = sut.write(value)

        // Then
        #expect(text == """
            {
              "size": [1080, 1920],
              "empty": [],
              "none": {},
              "glyphs": [
                [1043, 21.4, 52],
                [3, 288.1, 52]
              ],
              "runs": [
                {
                  "font": "/a.ttc",
                  "on": true,
                  "stroke": null
                }
              ]
            }

            """)
        #expect(try reader.read(text) == value)
    }

    @Test("the same value is written as the same bytes")
    func writesSameBytes() throws {
        // Given
        let value = try reader.read(#"{ "b": [0.1, "x", { "c": -0.0 }], "a": 13.95 }"#)

        // When
        let first = sut.write(value)
        let second = sut.write(try reader.read(first))

        // Then
        #expect(Data(first.utf8) == Data(second.utf8))
    }
}
