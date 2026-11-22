//
//  BidiResolver.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// Resolves the embedding levels of UAX #9 over text in logical order, and orders the characters of a line visually.
// Every paragraph separator ends a paragraph (P1), and every paragraph is resolved at the one paragraph embedding level
// it is given. A character that rule X9 removes takes the level of the character before it in its paragraph, or the
// paragraph embedding level when none is, so every scalar has a level and the removed ones break no run of levels.
struct BidiResolver: Sendable {
    // An entry of the directional status stack of X1.
    private struct Status {
        let level: Int
        let override: BidiClass?
        let isIsolate: Bool
    }

    // MARK: - Property
    private static let maxDepth = 125
    // BD16 pairs brackets with a stack of this many openings.
    private static let maxOpenings = 63
    private static let strong: [BidiClass] = [.leftToRight, .rightToLeft, .arabicLetter]
    private static let embeddings: [BidiClass] = [
        .leftToRightEmbedding, .rightToLeftEmbedding, .leftToRightOverride, .rightToLeftOverride
    ]
    private static let initiators: [BidiClass] = [.leftToRightIsolate, .rightToLeftIsolate, .firstStrongIsolate]
    private static let removed: [BidiClass] = embeddings + [.popDirectionalFormat, .boundaryNeutral]
    private static let separatorsAndTerminators: [BidiClass] = [
        .europeanSeparator, .europeanTerminator, .commonSeparator
    ]
    private static let neutralsAndIsolates: [BidiClass] = [
        .paragraphSeparator, .segmentSeparator, .whiteSpace, .otherNeutral, .popDirectionalIsolate
    ] + initiators
    // L1 sets these at the paragraph embedding level where they end a line or come before a separator, with the
    // characters X9 removes, which lie among them.
    private static let trailing: [BidiClass] = [.whiteSpace, .popDirectionalIsolate] + initiators + removed

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // P2 and P3: the level of the first strong character outside an isolate in the first paragraph that holds one, or
    // nil when none does.
    func paragraphLevel(of scalars: [Unicode.Scalar]) -> Int? {
        let classes = scalars.map(BidiClass.init)

        return paragraphs(of: classes).lazy.compactMap { paragraph in
            self.firstStrongLevel(in: classes[paragraph], isIsolate: false)
        }
        .first
    }

    // X1 to I2 over every paragraph at `paragraphLevel`, the level of each scalar before the lines are broken.
    func levels(
        of scalars: [Unicode.Scalar],
        paragraphLevel: Int
    ) -> [Int] {
        let classes = scalars.map(BidiClass.init)

        return paragraphs(of: classes).flatMap { paragraph in
            levels(of: Array(scalars[paragraph]), classes: Array(classes[paragraph]), paragraphLevel: paragraphLevel)
        }
    }

    // L1 over each of `lines`, ranges of `scalars` in logical order, on the levels `levels(of:paragraphLevel:)` gave.
    func lineLevels(
        of scalars: [Unicode.Scalar],
        levels: [Int],
        lines: [Range<Int>],
        paragraphLevel: Int
    ) -> [Int] {
        let classes = scalars.map(BidiClass.init)
        var lineLevels = levels
        for line in lines {
            var isTrailing = true
            for index in line.reversed() {
                if classes[index] == .segmentSeparator || classes[index] == .paragraphSeparator {
                    lineLevels[index] = paragraphLevel
                    isTrailing = true
                } else if Self.trailing.contains(classes[index]) {
                    if isTrailing {
                        lineLevels[index] = paragraphLevel
                    }
                } else {
                    isTrailing = false
                }
            }
        }

        return lineLevels
    }

    // L2: the indices of a line's characters from left to right, given their levels in logical order.
    func visualOrder(of levels: [Int]) -> [Int] {
        var order = Array(levels.indices)
        guard let highest = levels.max(), let lowestOdd = levels.filter({ $0 % 2 == 1 }).min() else { return order }

        for level in stride(from: highest, through: lowestOdd, by: -1) {
            var start = 0
            while start < order.count {
                guard levels[order[start]] >= level else {
                    start += 1
                    continue
                }

                var end = start
                while end < order.count && levels[order[end]] >= level {
                    end += 1
                }
                order[start..<end].reverse()
                start = end
            }
        }

        return order
    }

    // MARK: - Private
    // P1: each paragraph keeps the separator that ends it.
    private func paragraphs(of classes: [BidiClass]) -> [Range<Int>] {
        var paragraphs: [Range<Int>] = []
        var start = 0
        for (index, bidiClass) in classes.enumerated() where bidiClass == .paragraphSeparator {
            paragraphs.append(start..<index + 1)
            start = index + 1
        }
        if start < classes.count {
            paragraphs.append(start..<classes.count)
        }

        return paragraphs
    }

    // P2 and P3, which X5c reads too over the text of an isolate, where its matching PDI ends the search.
    private func firstStrongLevel(
        in classes: ArraySlice<BidiClass>,
        isIsolate: Bool
    ) -> Int? {
        var depth = 0
        for bidiClass in classes {
            if depth == 0 && Self.strong.contains(bidiClass) {
                return bidiClass == .leftToRight ? 0 : 1
            }
            if Self.initiators.contains(bidiClass) {
                depth += 1
            } else if bidiClass == .popDirectionalIsolate {
                if depth > 0 {
                    depth -= 1
                } else if isIsolate {
                    return nil
                }
            }
        }

        return nil
    }

    private func levels(
        of scalars: [Unicode.Scalar],
        classes: [BidiClass],
        paragraphLevel: Int
    ) -> [Int] {
        let matches = matchingIsolates(classes)
        let (embeddingLevels, types) = explicitLevels(classes, paragraphLevel: paragraphLevel)
        let kept = classes.indices.filter { !Self.removed.contains(classes[$0]) }
        let positions = Dictionary(uniqueKeysWithValues: kept.enumerated().map { ($1, $0) })
        var levels = embeddingLevels
        for sequence in isolatingRunSequences(kept: kept, levels: embeddingLevels, classes: classes, matches: matches) {
            let first = positions[sequence[0]] ?? 0
            let last = positions[sequence[sequence.count - 1]] ?? 0
            let before = first > 0 ? embeddingLevels[kept[first - 1]] : paragraphLevel
            let after = last + 1 < kept.count && !Self.initiators.contains(classes[kept[last]])
                ? embeddingLevels[kept[last + 1]]
                : paragraphLevel
            resolve(sequence, scalars: scalars, types: types, levelBefore: before, levelAfter: after, levels: &levels)
        }

        var previous = paragraphLevel
        for index in classes.indices {
            if Self.removed.contains(classes[index]) {
                levels[index] = previous
            }
            previous = levels[index]
        }

        return levels
    }

    // BD9: each isolate initiator and the PDI that closes it.
    private func matchingIsolates(_ classes: [BidiClass]) -> [Int: Int] {
        var open: [Int] = []
        var matches: [Int: Int] = [:]
        for (index, bidiClass) in classes.enumerated() {
            if Self.initiators.contains(bidiClass) {
                open.append(index)
            } else if bidiClass == .popDirectionalIsolate, let initiator = open.popLast() {
                matches[initiator] = index
            }
        }

        return matches
    }

    // X1 to X8: the embedding level of each character, and its type once overrides apply.
    private func explicitLevels(
        _ classes: [BidiClass],
        paragraphLevel: Int
    ) -> (levels: [Int], types: [BidiClass]) {
        var levels = Array(repeating: paragraphLevel, count: classes.count)
        var types = classes
        var stack = [Status(level: paragraphLevel, override: nil, isIsolate: false)]
        var overflowIsolates = 0
        var overflowEmbeddings = 0
        var validIsolates = 0

        for (index, bidiClass) in classes.enumerated() {
            let last = stack[stack.count - 1]
            switch bidiClass {
            case .leftToRightEmbedding, .rightToLeftEmbedding, .leftToRightOverride, .rightToLeftOverride:
                let isRightToLeft = bidiClass == .rightToLeftEmbedding || bidiClass == .rightToLeftOverride
                let level = nextLevel(after: last.level, isOdd: isRightToLeft)
                if level <= Self.maxDepth && overflowIsolates == 0 && overflowEmbeddings == 0 {
                    let override: BidiClass? = switch bidiClass {
                    case .leftToRightOverride: .leftToRight
                    case .rightToLeftOverride: .rightToLeft
                    default: nil
                    }
                    stack.append(Status(level: level, override: override, isIsolate: false))
                } else if overflowIsolates == 0 {
                    overflowEmbeddings += 1
                }

            case .leftToRightIsolate, .rightToLeftIsolate, .firstStrongIsolate:
                levels[index] = last.level
                types[index] = last.override ?? bidiClass
                let isRightToLeft = bidiClass == .rightToLeftIsolate
                    || bidiClass == .firstStrongIsolate
                        && firstStrongLevel(in: classes[(index + 1)...], isIsolate: true) == 1
                let level = nextLevel(after: last.level, isOdd: isRightToLeft)
                if level <= Self.maxDepth && overflowIsolates == 0 && overflowEmbeddings == 0 {
                    validIsolates += 1
                    stack.append(Status(level: level, override: nil, isIsolate: true))
                } else {
                    overflowIsolates += 1
                }

            case .popDirectionalIsolate:
                if overflowIsolates > 0 {
                    overflowIsolates -= 1
                } else if validIsolates > 0 {
                    overflowEmbeddings = 0
                    while !stack[stack.count - 1].isIsolate {
                        stack.removeLast()
                    }
                    stack.removeLast()
                    validIsolates -= 1
                }
                let current = stack[stack.count - 1]
                levels[index] = current.level
                types[index] = current.override ?? bidiClass

            case .popDirectionalFormat:
                if overflowIsolates == 0 {
                    if overflowEmbeddings > 0 {
                        overflowEmbeddings -= 1
                    } else if !last.isIsolate && stack.count > 1 {
                        stack.removeLast()
                    }
                }

            case .paragraphSeparator, .boundaryNeutral:
                break

            default:
                levels[index] = last.level
                types[index] = last.override ?? bidiClass
            }
        }

        return (levels, types)
    }

    private func nextLevel(
        after level: Int,
        isOdd: Bool
    ) -> Int {
        isOdd ? (level + 1) | 1 : (level + 2) & ~1
    }

    // X10 and BD13: the characters X9 keeps cut into level runs, each run that ends with an isolate initiator joined to
    // the run its matching PDI starts.
    private func isolatingRunSequences(
        kept: [Int],
        levels: [Int],
        classes: [BidiClass],
        matches: [Int: Int]
    ) -> [[Int]] {
        let runs = kept.reduce(into: [[Int]]()) { runs, index in
            if let last = runs.last?.last, levels[last] == levels[index] {
                runs[runs.count - 1].append(index)
            } else {
                runs.append([index])
            }
        }
        let runStarting = Dictionary(uniqueKeysWithValues: runs.enumerated().map { ($1[0], $0) })

        var joined = Set<Int>()
        var sequences: [[Int]] = []
        for (number, run) in runs.enumerated() where !joined.contains(number) {
            var sequence = run
            while
                let last = sequence.last,
                Self.initiators.contains(classes[last]),
                let match = matches[last],
                let next = runStarting[match]
            {
                joined.insert(next)
                sequence += runs[next]
            }
            sequences.append(sequence)
        }

        return sequences
    }

    // W1 to I2 over one isolating run sequence, `sequence` holding the indices of its characters in order, between
    // the levels X10 compares its own with to find sos and eos.
    private func resolve(
        _ sequence: [Int],
        scalars: [Unicode.Scalar],
        types: [BidiClass],
        levelBefore: Int,
        levelAfter: Int,
        levels: inout [Int]
    ) {
        let level = levels[sequence[0]]
        let embedding = direction(of: level)
        let startOfSequence = direction(of: max(level, levelBefore))
        let endOfSequence = direction(of: max(level, levelAfter))

        let explicit = sequence.map { types[$0] }
        var resolved = weakTypes(explicit, startOfSequence: startOfSequence)
        pairBrackets(
            &resolved,
            explicit: explicit,
            scalars: sequence.map { scalars[$0] },
            embedding: embedding,
            startOfSequence: startOfSequence
        )
        neutralTypes(&resolved, embedding: embedding, startOfSequence: startOfSequence, endOfSequence: endOfSequence)

        for (position, index) in sequence.enumerated() {
            levels[index] = implicitLevel(level, type: resolved[position])
        }
    }

    private func direction(of level: Int) -> BidiClass {
        level % 2 == 0 ? .leftToRight : .rightToLeft
    }

    // W1 to W7.
    private func weakTypes(
        _ explicit: [BidiClass],
        startOfSequence: BidiClass
    ) -> [BidiClass] {
        var types = explicit
        for position in types.indices where types[position] == .nonspacingMark {
            if position == 0 {
                types[position] = startOfSequence
            } else if Self.initiators.contains(types[position - 1]) || types[position - 1] == .popDirectionalIsolate {
                types[position] = .otherNeutral
            } else {
                types[position] = types[position - 1]
            }
        }

        var lastStrong = startOfSequence
        for position in types.indices {
            if Self.strong.contains(types[position]) {
                lastStrong = types[position]
            } else if types[position] == .europeanNumber && lastStrong == .arabicLetter {
                types[position] = .arabicNumber
            }
        }
        types = types.map { $0 == .arabicLetter ? .rightToLeft : $0 }

        for position in types.indices.dropFirst().dropLast() {
            let pair = (types[position - 1], types[position + 1])
            switch (types[position], pair) {
            case (.europeanSeparator, (.europeanNumber, .europeanNumber)),
                 (.commonSeparator, (.europeanNumber, .europeanNumber)):
                types[position] = .europeanNumber

            case (.commonSeparator, (.arabicNumber, .arabicNumber)):
                types[position] = .arabicNumber

            default:
                break
            }
        }

        var start = 0
        while start < types.count {
            guard types[start] == .europeanTerminator else {
                start += 1
                continue
            }

            var end = start
            while end < types.count && types[end] == .europeanTerminator {
                end += 1
            }
            if start > 0 && types[start - 1] == .europeanNumber || end < types.count && types[end] == .europeanNumber {
                types.replaceSubrange(start..<end, with: repeatElement(.europeanNumber, count: end - start))
            }
            start = end
        }

        types = types.map { Self.separatorsAndTerminators.contains($0) ? .otherNeutral : $0 }

        lastStrong = startOfSequence
        for position in types.indices {
            if types[position] == .leftToRight || types[position] == .rightToLeft {
                lastStrong = types[position]
            } else if types[position] == .europeanNumber && lastStrong == .leftToRight {
                types[position] = .leftToRight
            }
        }

        return types
    }

    // BD16 and N0: each bracket pair takes the embedding direction when a strong type of it lies inside, or else the
    // other direction when that lies inside and before the pair too, and the marks after a bracket follow it.
    private func pairBrackets(
        _ types: inout [BidiClass],
        explicit: [BidiClass],
        scalars: [Unicode.Scalar],
        embedding: BidiClass,
        startOfSequence: BidiClass
    ) {
        for (opening, closing) in bracketPairs(types, scalars: scalars) {
            let inside = types[(opening + 1)..<closing].compactMap(strongDirection)
            let pairDirection: BidiClass
            if inside.contains(embedding) {
                pairDirection = embedding
            } else if let opposite = inside.first {
                let context = types[..<opening].reversed().lazy.compactMap(strongDirection).first ?? startOfSequence
                pairDirection = context == opposite ? opposite : embedding
            } else {
                continue
            }

            for bracket in [opening, closing] {
                types[bracket] = pairDirection
                var mark = bracket + 1
                while mark < types.count && explicit[mark] == .nonspacingMark {
                    types[mark] = pairDirection
                    mark += 1
                }
            }
        }
    }

    // BD16: the bracket pairs of an isolating run sequence, in the order of their opening brackets.
    private func bracketPairs(
        _ types: [BidiClass],
        scalars: [Unicode.Scalar]
    ) -> [(Int, Int)] {
        var openings: [(opening: UInt32, position: Int)] = []
        var pairs: [(Int, Int)] = []
        for position in types.indices where types[position] == .otherNeutral {
            guard let bracket = PairedBracket(scalars[position]) else { continue }

            switch bracket.type {
            case .opening:
                guard openings.count < Self.maxOpenings else { return pairs.sorted { $0.0 < $1.0 } }

                openings.append((bracket.opening, position))

            case .closing:
                if let match = openings.lastIndex(where: { $0.opening == bracket.opening }) {
                    pairs.append((openings[match].position, position))
                    openings.removeSubrange(match...)
                }
            }
        }

        return pairs.sorted { $0.0 < $1.0 }
    }

    // N0 to N2 read European and Arabic numbers as right to left.
    private func strongDirection(_ type: BidiClass) -> BidiClass? {
        switch type {
        case .leftToRight:
            .leftToRight

        case .rightToLeft, .europeanNumber, .arabicNumber:
            .rightToLeft

        default:
            nil
        }
    }

    // N1 and N2.
    private func neutralTypes(
        _ types: inout [BidiClass],
        embedding: BidiClass,
        startOfSequence: BidiClass,
        endOfSequence: BidiClass
    ) {
        var start = 0
        while start < types.count {
            guard Self.neutralsAndIsolates.contains(types[start]) else {
                start += 1
                continue
            }

            var end = start
            while end < types.count && Self.neutralsAndIsolates.contains(types[end]) {
                end += 1
            }
            let before = start > 0 ? strongDirection(types[start - 1]) ?? embedding : startOfSequence
            let after = end < types.count ? strongDirection(types[end]) ?? embedding : endOfSequence
            let neutralDirection = before == after ? before : embedding
            types.replaceSubrange(start..<end, with: repeatElement(neutralDirection, count: end - start))
            start = end
        }
    }

    // I1 and I2.
    private func implicitLevel(
        _ level: Int,
        type: BidiClass
    ) -> Int {
        switch (level % 2 == 0, type) {
        case (true, .rightToLeft):
            level + 1

        case (true, .europeanNumber), (true, .arabicNumber):
            level + 2

        case (false, .leftToRight), (false, .europeanNumber), (false, .arabicNumber):
            level + 1

        default:
            level
        }
    }
}
