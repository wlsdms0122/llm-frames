//
//  LineBreaker.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Finds where lines may break by the pair rules of UAX #14, LB4 to LB31, and which of those breaks fall inside a word.
struct LineBreaker: Sendable {
    // MARK: - Property
    private static let hardBreaks: [LineBreakClass] = [.mandatoryBreak, .carriageReturn, .lineFeed, .nextLine]
    private static let closing: [LineBreakClass] = [
        .closePunctuation, .closeParenthesis, .exclamation, .infixSeparator, .symbol
    ]
    private static let jamo: [LineBreakClass] = [
        .leadingJamo, .vowelJamo, .trailingJamo, .twoJamoSyllable, .threeJamoSyllable
    ]
    // A break between letter units of these classes falls inside a word, Hangul counting as ideographic.
    private static let wordLetters: [LineBreakClass] = [.numeric, .alphabetic, .ideographic] + jamo
    // LB30 keeps an opening bracket on a letter only when the bracket is not wide, and wide forms start here.
    private static let firstWide: UInt32 = 0x2E80
    private static let numberParts: [LineBreakClass] = [
        .prefixNumeric, .postfixNumeric, .openPunctuation, .hyphen, .numeric, .symbol, .infixSeparator
    ]

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // The break before each scalar. The first is always prohibited, since a line holds at least one scalar.
    func breaks(in scalars: [Unicode.Scalar]) -> [LineBreak] {
        let written = scalars.map(LineBreakClass.init)
        let classes = attached(written)

        return scalars.indices.map { index in
            guard index > 0 else { return .prohibited }

            let lineBreak = lineBreak(before: index, classes: classes, written: written, scalars: scalars)
            let isInsideWord = [classes[index - 1], classes[index]].allSatisfy(Self.wordLetters.contains)

            return lineBreak == .allowed && isInsideWord ? .insideWord : lineBreak
        }
    }

    // MARK: - Private
    // LB9 and LB10: a combining mark or joiner takes the class of the scalar it follows, except after a space or a
    // break, where it is alphabetic.
    private func attached(_ written: [LineBreakClass]) -> [LineBreakClass] {
        written.reduce(into: [LineBreakClass]()) { classes, current in
            guard current == .combiningMark || current == .zeroWidthJoiner else {
                classes.append(current)
                return
            }
            guard let previous = classes.last, !(Self.hardBreaks + [.space, .zeroWidthSpace]).contains(previous) else {
                classes.append(.alphabetic)
                return
            }

            classes.append(previous)
        }
    }

    private func lineBreak(
        before index: Int,
        classes: [LineBreakClass],
        written: [LineBreakClass],
        scalars: [Unicode.Scalar]
    ) -> LineBreak {
        let before = classes[index - 1]
        let after = classes[index]
        // The class before the spaces that end at `index`, for the rules that look through them.
        let beforeSpaces = classes[..<index].last { $0 != .space } ?? .space

        if before == .carriageReturn && after == .lineFeed {
            return .prohibited
        }
        if Self.hardBreaks.contains(before) {
            return .mandatory
        }
        if Self.hardBreaks.contains(after) || after == .space || after == .zeroWidthSpace {
            return .prohibited
        }
        if beforeSpaces == .zeroWidthSpace {
            return .allowed
        }
        if written[index - 1] == .zeroWidthJoiner {
            return .prohibited
        }
        if
            (written[index] == .combiningMark || written[index] == .zeroWidthJoiner)
                && !(Self.hardBreaks + [.space, .zeroWidthSpace]).contains(before)
        {
            return .prohibited
        }

        return pairBreak(
            before: before,
            after: after,
            beforeSpaces: beforeSpaces,
            next: classes.indices.contains(index + 1) ? classes[index + 1] : nil,
            regionalIndicators: classes[..<index].reversed().prefix { $0 == .regionalIndicator }.count,
            isWide: scalars[index].value >= Self.firstWide
        )
    }

    // LB11 to LB31, once breaks, spaces and attached marks are settled.
    private func pairBreak(
        before: LineBreakClass,
        after: LineBreakClass,
        beforeSpaces: LineBreakClass,
        next: LineBreakClass?,
        regionalIndicators: Int,
        isWide: Bool
    ) -> LineBreak {
        switch (before, after) {
        case (.wordJoiner, _), (_, .wordJoiner), (.glue, _):
            return .prohibited

        case (_, .glue) where ![.space, .breakAfter, .hyphen].contains(before):
            return .prohibited

        case (_, let after) where Self.closing.contains(after):
            return .prohibited

        default:
            break
        }

        switch (beforeSpaces, after) {
        case (.openPunctuation, _), (.quotation, .openPunctuation), (.closePunctuation, .nonstarter),
             (.closeParenthesis, .nonstarter), (.breakBoth, .breakBoth):
            return .prohibited

        default:
            break
        }

        if before == .space {
            return .allowed
        }

        return letterBreak(
            before: before,
            after: after,
            next: next,
            regionalIndicators: regionalIndicators,
            isWide: isWide
        )
    }

    // LB19 to LB31: quotations, hyphens, numbers, Hangul, letters and emoji.
    private func letterBreak(
        before: LineBreakClass,
        after: LineBreakClass,
        next: LineBreakClass?,
        regionalIndicators: Int,
        isWide: Bool
    ) -> LineBreak {
        switch (before, after) {
        case (.quotation, _), (_, .quotation),
             (_, .breakAfter), (_, .hyphen), (_, .nonstarter), (.breakBefore, _),
             (_, .inseparable),
             (.alphabetic, .numeric), (.numeric, .alphabetic),
             (.prefixNumeric, .ideographic), (.prefixNumeric, .emojiModifier),
             (.ideographic, .postfixNumeric), (.emojiModifier, .postfixNumeric),
             (.prefixNumeric, .alphabetic), (.postfixNumeric, .alphabetic),
             (.alphabetic, .prefixNumeric), (.alphabetic, .postfixNumeric),
             (.numeric, .postfixNumeric), (.numeric, .prefixNumeric),
             (.closePunctuation, .postfixNumeric), (.closeParenthesis, .postfixNumeric),
             (.closePunctuation, .prefixNumeric), (.closeParenthesis, .prefixNumeric),
             (.leadingJamo, .leadingJamo), (.leadingJamo, .vowelJamo),
             (.leadingJamo, .twoJamoSyllable), (.leadingJamo, .threeJamoSyllable),
             (.vowelJamo, .vowelJamo), (.vowelJamo, .trailingJamo),
             (.twoJamoSyllable, .vowelJamo), (.twoJamoSyllable, .trailingJamo),
             (.trailingJamo, .trailingJamo), (.threeJamoSyllable, .trailingJamo),
             (.alphabetic, .alphabetic), (.infixSeparator, .alphabetic),
             (.closeParenthesis, .alphabetic), (.closeParenthesis, .numeric),
             (.ideographic, .emojiModifier):
            return .prohibited

        case (_, .numeric) where Self.numberParts.contains(before):
            return .prohibited

        case (.prefixNumeric, .openPunctuation), (.postfixNumeric, .openPunctuation):
            return next == .numeric ? .prohibited : .allowed

        case (let before, .postfixNumeric) where Self.jamo.contains(before):
            return .prohibited

        case (.prefixNumeric, let after) where Self.jamo.contains(after):
            return .prohibited

        case (.alphabetic, .openPunctuation), (.numeric, .openPunctuation):
            return isWide ? .allowed : .prohibited

        case (.regionalIndicator, .regionalIndicator):
            return regionalIndicators % 2 == 1 ? .prohibited : .allowed

        default:
            return .allowed
        }
    }
}
