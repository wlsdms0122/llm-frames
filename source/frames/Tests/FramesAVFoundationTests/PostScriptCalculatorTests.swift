//
//  PostScriptCalculatorTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
@testable import FramesAVFoundation
import Testing

// The operators of a PostScript calculator function as ISO 32000-1 7.10.5.2 lists them.
@Suite("PostScriptCalculator Tests")
struct PostScriptCalculatorTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "each operator leaves what ISO 32000-1 7.10.5.2 gives",
        arguments: [
            ("{ 7 2 idiv 7 2 mod -7 2 idiv -7 2 mod }", [], [3, 1, -3, -1]),
            ("{ 2 3 add 2 3 sub 2 3 mul 3 2 div }", [], [5, -1, 6, 1.5]),
            ("{ 1 0 atan 0 -1 atan -1 0 atan }", [], [90, 180, 270]),
            ("{ 2 10 exp 100 log 1 ln 9 sqrt }", [], [1024, 2, 0, 3]),
            ("{ 2.5 round -2.5 round 2.7 truncate -2.7 floor 2.2 ceiling }", [], [3, -2, 2, -3, 3]),
            ("{ 2.7 cvi 3 cvr -4 abs 4 neg -2.5 abs }", [], [2, 3, 4, -4, 2.5]),
            ("{ 1 2 lt { 10 } { 20 } ifelse 1 2 gt { 30 } if }", [], [10]),
            ("{ 3 2 ge 2 2 le and 1 2 eq or 1 1 ne not and { 1 } { 0 } ifelse }", [], [1]),
            ("{ true false xor not { 1 } { 0 } ifelse }", [], [0]),
            ("{ 12 10 and 12 10 or 12 10 xor 1 3 bitshift 8 -2 bitshift 0 not }", [], [8, 14, 6, 8, 2, -1]),
            ("{ 1 2 3 3 1 roll 4 5 6 3 -1 roll }", [], [3, 1, 2, 5, 6, 4]),
            ("{ 1 2 2 copy 0 index }", [], [1, 2, 1, 2, 2]),
            ("{ 1 2 exch pop dup }", [], [2, 2]),
            ("{ exch % the inputs swapped\n }", [0.25, 0.75], [0.75, 0.25])
        ] as [(String, [Double], [Double])]
    )
    func runsOperators(
        program: String,
        inputs: [Double],
        expected: [Double]
    ) throws {
        // Given
        let sut = try #require(PostScriptCalculator(program))

        // When
        let outputs = try #require(sut.run(inputs))

        // Then
        #expect(outputs.count == expected.count)
        #expect(zip(outputs, expected).allSatisfy { abs($0 - $1) < 1e-12 })
    }

    @Test("sine and cosine take degrees")
    func takesDegrees() throws {
        // Given
        let sut = try #require(PostScriptCalculator("{ 30 sin 60 cos }"))

        // When
        let outputs = try #require(sut.run([]))

        // Then
        #expect(outputs.count == 2)
        #expect(outputs.allSatisfy { abs($0 - 0.5) < 1e-12 })
    }

    @Test(
        "a program that runs out of operands, divides by zero or takes an operand of the wrong type gives no outputs",
        arguments: ["{ add }", "{ 1 0 div }", "{ 1 0 idiv }", "{ true 1 add }", "{ 1 { 2 } if }", "{ -1 sqrt }"]
    )
    func stopsOnErrors(program: String) throws {
        // Given
        let sut = try #require(PostScriptCalculator(program))

        // When
        let outputs = sut.run([])

        // Then
        #expect(outputs == nil)
    }

    @Test(
        "integer arithmetic past the integers stops as an error, and a shift of any length leaves an integer",
        arguments: [
            ("{ -9223372036854775807 1 sub -1 idiv }", nil),
            ("{ -9223372036854775807 1 sub -1 mod }", nil),
            ("{ 1 -9223372036854775807 1 sub bitshift }", [0]),
            ("{ 1 64 bitshift 1 -64 bitshift -8 -1 bitshift }", [0, 0, -4]),
            ("{ 9223372036854775807 2 mul }", [0x1p64])
        ] as [(String, [Double]?)]
    )
    func stopsOnIntegerOverflow(
        program: String,
        expected: [Double]?
    ) throws {
        // Given
        let sut = try #require(PostScriptCalculator(program))

        // When
        let outputs = sut.run([])

        // Then
        #expect(outputs == expected)
    }

    @Test(
        "a program that is not one procedure, or that names an operator outside 7.10.5.2, is not read",
        arguments: ["1 2 add", "{ 1 2 add", "{ 1 foo }", "{ 1 { 2 } }", "{ 1 2 add } 3", "{ { 1 } { 2 } { 3 } ifelse }"]
    )
    func refusesPrograms(program: String) {
        // Given
        // When
        let sut = PostScriptCalculator(program)

        // Then
        #expect(sut == nil)
    }
}
