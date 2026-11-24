//
//  AnimationPlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `units` is a title's unit, stagger and order when its entrance and exit play by unit, and nil otherwise.
struct AnimationPlan: Equatable, Sendable {
    // MARK: - Property
    static let none = AnimationPlan(entrance: nil, loop: nil, exit: nil, units: nil)

    let entrance: PresetSpan?
    let loop: PresetSpan?
    let exit: PresetSpan?
    let units: UnitStagger?

    var isEmpty: Bool {
        entrance == nil && loop == nil && exit == nil
    }

    // MARK: - Initializer
    init(
        entrance: PresetSpan?,
        loop: PresetSpan?,
        exit: PresetSpan?,
        units: UnitStagger?
    ) {
        self.entrance = entrance
        self.loop = loop
        self.exit = exit
        self.units = units
    }

    // MARK: - Public
    // MARK: - Private
}
