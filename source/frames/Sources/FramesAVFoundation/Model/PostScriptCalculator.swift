//
//  PostScriptCalculator.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// The program of a PostScript calculator function (ISO 32000-1 7.10.5), run on an operand stack: its inputs pushed in
// order, its outputs the values left on the stack, bottom first. It knows the operators of 7.10.5.2: arithmetic, the
// relational, boolean and bitwise operators, `if` and `ifelse`, and the stack operators. An angle is in degrees.
struct PostScriptCalculator: Equatable, Sendable {
    // MARK: - Property
    let program: [PostScriptInstruction]

    private static let operators: Set<String> = [
        "abs", "add", "atan", "ceiling", "cos", "cvi", "cvr", "div", "exp", "floor", "idiv", "ln", "log", "mod", "mul",
        "neg", "round", "sin", "sqrt", "sub", "truncate", "and", "bitshift", "eq", "ge", "gt", "le", "lt", "ne", "not",
        "or", "xor", "copy", "dup", "exch", "index", "pop", "roll"
    ]
    private static let stackLimit = 1000

    // MARK: - Initializer
    // The program `text` writes as one procedure in braces, nil where it is not one or names an operator 7.10.5.2
    // does not list.
    init?(_ text: String) {
        var tokens = Self.tokens(of: text)[...]
        guard tokens.popFirst() == "{", let program = Self.procedure(&tokens), tokens.isEmpty else { return nil }

        self.program = program
    }

    // MARK: - Public
    // The values the program leaves for `inputs`, nil where it stops on an error: an operand of the wrong type, a stack
    // with too few operands or too many, a division by zero, or a result that is not a finite number.
    func run(_ inputs: [Double]) -> [Double]? {
        var stack = inputs.map(PostScriptValue.real)
        guard Self.run(program, on: &stack) else { return nil }
        let outputs = stack.compactMap(\.number)
        guard outputs.count == stack.count, outputs.allSatisfy(\.isFinite) else { return nil }

        return outputs
    }

    // MARK: - Private
    private static func tokens(of text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var isComment = false
        for character in text {
            if isComment {
                if character == "\n" || character == "\r" { isComment = false }
                continue
            }
            if character == "{" || character == "}" || character == "%" || character.isWhitespace {
                if !current.isEmpty { tokens.append(current) }
                current = ""
                if character == "%" { isComment = true }
                if character == "{" || character == "}" { tokens.append(String(character)) }
                continue
            }
            current.append(character)
        }
        if !current.isEmpty { tokens.append(current) }

        return tokens
    }

    // The instructions up to the closing brace of a procedure whose opening brace is read.
    private static func procedure(_ tokens: inout ArraySlice<String>) -> [PostScriptInstruction]? {
        var instructions: [PostScriptInstruction] = []
        var procedures: [[PostScriptInstruction]] = []
        while let token = tokens.popFirst() {
            switch token {
            case "}":
                guard procedures.isEmpty else { return nil }
                return instructions

            case "{":
                guard let inner = procedure(&tokens) else { return nil }
                procedures.append(inner)

            case "if":
                guard procedures.count == 1 else { return nil }
                instructions.append(.conditional(then: procedures[0], otherwise: nil))
                procedures = []

            case "ifelse":
                guard procedures.count == 2 else { return nil }
                instructions.append(.conditional(then: procedures[0], otherwise: procedures[1]))
                procedures = []

            default:
                guard procedures.isEmpty, let instruction = instruction(token) else { return nil }
                instructions.append(instruction)
            }
        }

        return nil
    }

    private static func instruction(_ token: String) -> PostScriptInstruction? {
        if token == "true" { return .operand(.boolean(true)) }
        if token == "false" { return .operand(.boolean(false)) }
        if operators.contains(token) { return .operation(token) }
        if let integer = Int(token) { return .operand(.integer(integer)) }
        if let real = Double(token), real.isFinite, token.first.map({ $0.isNumber || "+-.".contains($0) }) == true {
            return .operand(.real(real))
        }

        return nil
    }

    private static func run(
        _ program: [PostScriptInstruction],
        on stack: inout [PostScriptValue]
    ) -> Bool {
        for instruction in program {
            switch instruction {
            case let .operand(value):
                stack.append(value)

            case let .operation(name):
                guard operate(name, on: &stack) else { return false }

            case let .conditional(then, otherwise):
                guard case let .boolean(condition)? = stack.popLast() else { return false }
                let chosen = condition ? then : otherwise ?? []
                guard run(chosen, on: &stack) else { return false }
            }
            guard stack.count <= stackLimit else { return false }
        }

        return true
    }

    // Runs the operator `name`, false where its operands are missing or of the wrong type.
    private static func operate(
        _ name: String,
        on stack: inout [PostScriptValue]
    ) -> Bool {
        switch name {
        case "dup":
            guard let top = stack.last else { return false }
            stack.append(top)
            return true

        case "pop":
            return stack.popLast() != nil

        case "exch":
            guard stack.count >= 2 else { return false }
            stack.swapAt(stack.count - 1, stack.count - 2)
            return true

        case "copy":
            guard case let .integer(count)? = stack.popLast(), count >= 0, count <= stack.count else { return false }
            stack.append(contentsOf: stack.suffix(count))
            return true

        case "index":
            guard case let .integer(depth)? = stack.popLast(), depth >= 0, depth < stack.count else { return false }
            stack.append(stack[stack.count - 1 - depth])
            return true

        case "roll":
            guard
                case let .integer(shift)? = stack.popLast(),
                case let .integer(count)? = stack.popLast(),
                count >= 0,
                count <= stack.count
            else {
                return false
            }
            guard count > 0 else { return true }
            let rolled = Array(stack.suffix(count))
            let offset = ((shift % count) + count) % count
            stack.removeLast(count)
            stack.append(contentsOf: rolled.suffix(offset) + rolled.prefix(count - offset))
            return true

        case "abs", "neg", "ceiling", "floor", "round", "truncate", "cvi", "cvr", "sqrt", "sin", "cos", "ln", "log",
            "not":
            guard let operand = stack.popLast(), let result = unary(name, operand) else { return false }
            stack.append(result)
            return true

        default:
            guard
                let second = stack.popLast(),
                let first = stack.popLast(),
                let result = binary(name, first, second)
            else {
                return false
            }
            stack.append(result)
            return true
        }
    }

    private static func unary(
        _ name: String,
        _ operand: PostScriptValue
    ) -> PostScriptValue? {
        if name == "not" {
            switch operand {
            case let .boolean(value):
                return .boolean(!value)

            case let .integer(value):
                return .integer(~value)

            case .real:
                return nil
            }
        }
        guard let x = operand.number else { return nil }

        switch (name, operand) {
        case let ("abs", .integer(value)):
            return value == .min ? .real(-Double(value)) : .integer(abs(value))

        case let ("neg", .integer(value)):
            return value == .min ? .real(-Double(value)) : .integer(-value)

        case ("ceiling", .integer), ("floor", .integer), ("round", .integer), ("truncate", .integer), ("cvi", .integer):
            return operand

        case ("abs", _):
            return .real(abs(x))

        case ("neg", _):
            return .real(-x)

        case ("ceiling", _):
            return .real(x.rounded(.up))

        case ("floor", _):
            return .real(x.rounded(.down))

        // PostScript rounds a half up, to the greater integer.
        case ("round", _):
            return .real((x + 0.5).rounded(.down))

        case ("truncate", _):
            return .real(x.rounded(.towardZero))

        case ("cvi", _):
            let truncated = x.rounded(.towardZero)
            guard truncated.isFinite, abs(truncated) < 0x1p62 else { return nil }
            return .integer(Int(truncated))

        case ("cvr", _):
            return .real(x)

        case ("sqrt", _):
            return x >= 0 ? .real(x.squareRoot()) : nil

        case ("sin", _):
            return .real(sin(x * .pi / 180))

        case ("cos", _):
            return .real(cos(x * .pi / 180))

        case ("ln", _):
            return x > 0 ? .real(Foundation.log(x)) : nil

        case ("log", _):
            return x > 0 ? .real(log10(x)) : nil

        default:
            return nil
        }
    }

    private static func binary(
        _ name: String,
        _ first: PostScriptValue,
        _ second: PostScriptValue
    ) -> PostScriptValue? {
        switch (name, first, second) {
        case let ("eq", .boolean(a), .boolean(b)):
            return .boolean(a == b)

        case let ("ne", .boolean(a), .boolean(b)):
            return .boolean(a != b)

        case let ("and", .boolean(a), .boolean(b)):
            return .boolean(a && b)

        case let ("or", .boolean(a), .boolean(b)):
            return .boolean(a || b)

        case let ("xor", .boolean(a), .boolean(b)):
            return .boolean(a != b)

        case let ("and", .integer(a), .integer(b)):
            return .integer(a & b)

        case let ("or", .integer(a), .integer(b)):
            return .integer(a | b)

        case let ("xor", .integer(a), .integer(b)):
            return .integer(a ^ b)

        case let ("bitshift", .integer(a), .integer(shift)):
            return .integer(shift >= 0 ? a << shift : a >> -shift)

        case let ("idiv", .integer(a), .integer(b)):
            return b == 0 ? nil : .integer(a / b)

        case let ("mod", .integer(a), .integer(b)):
            return b == 0 ? nil : .integer(a % b)

        case let ("add", .integer(a), .integer(b)):
            let (sum, overflows) = a.addingReportingOverflow(b)
            return overflows ? .real(Double(a) + Double(b)) : .integer(sum)

        case let ("sub", .integer(a), .integer(b)):
            let (difference, overflows) = a.subtractingReportingOverflow(b)
            return overflows ? .real(Double(a) - Double(b)) : .integer(difference)

        case let ("mul", .integer(a), .integer(b)):
            let (product, overflows) = a.multipliedReportingOverflow(by: b)
            return overflows ? .real(Double(a) * Double(b)) : .integer(product)

        default:
            break
        }
        guard let a = first.number, let b = second.number else { return nil }

        switch name {
        case "add":
            return .real(a + b)

        case "sub":
            return .real(a - b)

        case "mul":
            return .real(a * b)

        case "div":
            return b == 0 ? nil : .real(a / b)

        // The angle whose tangent is a / b, from 0 to 360 degrees.
        case "atan":
            guard a != 0 || b != 0 else { return nil }
            let degrees = atan2(a, b) * 180 / .pi
            return .real(degrees < 0 ? degrees + 360 : degrees)

        case "exp":
            return .real(pow(a, b))

        case "eq":
            return .boolean(a == b)

        case "ne":
            return .boolean(a != b)

        case "ge":
            return .boolean(a >= b)

        case "gt":
            return .boolean(a > b)

        case "le":
            return .boolean(a <= b)

        case "lt":
            return .boolean(a < b)

        default:
            return nil
        }
    }
}
