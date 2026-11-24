//
//  UnitSchedule.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// When each of a title's `count` units plays its entrance and its exit in a window. Each unit takes a rank by `order`,
// and with R the largest rank, unit i enters from start + rank(i) × stagger for the entrance's seconds and leaves from
// end - exit - (R - rank(i)) × exit stagger for the exit's seconds, so the units leave in the order they came. With E
// the entrance and X the exit of all the units, staggers included, an exit that does not fit in what the entrance
// leaves of the window has its seconds and its stagger scaled by (length - E) / X, and there is none when E alone fills
// the window. A span the animation lacks takes no time.
struct UnitSchedule: Equatable, Sendable {
    // MARK: - Property
    let window: TimeRange
    let count: Int
    // By unit index in reading order, empty for a title with no unit.
    let ranks: [Int]
    // R, 0 for a title with no unit.
    let largestRank: Int
    let entrance: Double
    let stagger: Double
    let exit: Double
    let exitStagger: Double

    // From the end of the last entrance to the start of the first exit, where the loop plays.
    var rest: TimeRange {
        let entered = entrance > 0 ? window.start + entrance + Double(largestRank) * stagger : window.start
        let leaving = exit > 0 ? window.end - exit - Double(largestRank) * exitStagger : window.end

        return TimeRange(start: min(entered, leaving), end: leaving)
    }

    // MARK: - Initializer
    init(
        animation: ResolvedAnimation,
        stagger: Double,
        order: UnitOrder,
        count: Int,
        in window: TimeRange
    ) {
        let ranks = order.ranks(count: count)
        let largestRank = ranks.max() ?? 0
        let later = Double(largestRank) * stagger
        let entrance = animation.entrance?.length ?? 0
        let exit = animation.exit?.length ?? 0
        let entering = entrance > 0 ? entrance + later : 0
        let leaving = exit > 0 ? exit + later : 0
        let room = window.length - entering
        let factor = room <= 0 ? 0 : (entering + leaving > window.length ? room / leaving : 1)

        self.window = window
        self.count = max(count, 1)
        self.ranks = ranks
        self.largestRank = largestRank
        self.entrance = entrance
        self.stagger = stagger
        self.exit = exit * factor
        self.exitStagger = stagger * factor
    }

    // MARK: - Public
    func entranceStart(of index: Int) -> Double {
        window.start + Double(rank(of: index)) * stagger
    }

    func exitStart(of index: Int) -> Double {
        window.end - exit - Double(largestRank - rank(of: index)) * exitStagger
    }

    // MARK: - Private
    private func rank(of index: Int) -> Int {
        ranks.indices.contains(index) ? ranks[index] : 0
    }
}
