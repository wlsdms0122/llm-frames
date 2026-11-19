//
//  UnitSchedule.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// When each of a title's `count` units plays its entrance and its exit in a window. Unit i enters from
// start + i × stagger for the entrance's seconds and leaves from end - exit - (count - 1 - i) × exit stagger for the
// exit's seconds. With E the entrance and X the exit of all the units, staggers included, an exit that does not fit in
// what the entrance leaves of the window has its seconds and its stagger scaled by (length - E) / X, and there is none
// when E alone fills the window. A span the animation lacks takes no time.
struct UnitSchedule: Equatable, Sendable {
    // MARK: - Property
    let window: TimeRange
    let count: Int
    let entrance: Double
    let stagger: Double
    let exit: Double
    let exitStagger: Double

    // From the end of the last unit's entrance to the start of the first unit's exit, where the loop plays.
    var rest: TimeRange {
        let entered = entrance > 0 ? window.start + entrance + Double(count - 1) * stagger : window.start
        let leaving = exit > 0 ? exitStart(of: 0) : window.end

        return TimeRange(start: min(entered, leaving), end: leaving)
    }

    // MARK: - Initializer
    init(
        animation: ResolvedAnimation,
        stagger: Double,
        count: Int,
        in window: TimeRange
    ) {
        let later = Double(max(count, 1) - 1) * stagger
        let entrance = animation.entrance?.length ?? 0
        let exit = animation.exit?.length ?? 0
        let entering = entrance > 0 ? entrance + later : 0
        let leaving = exit > 0 ? exit + later : 0
        let room = window.length - entering
        let factor = room <= 0 ? 0 : (entering + leaving > window.length ? room / leaving : 1)

        self.window = window
        self.count = max(count, 1)
        self.entrance = entrance
        self.stagger = stagger
        self.exit = exit * factor
        self.exitStagger = stagger * factor
    }

    // MARK: - Public
    func entranceStart(of index: Int) -> Double {
        window.start + Double(index) * stagger
    }

    func exitStart(of index: Int) -> Double {
        window.end - exit - Double(count - 1 - index) * exitStagger
    }

    // MARK: - Private
}
