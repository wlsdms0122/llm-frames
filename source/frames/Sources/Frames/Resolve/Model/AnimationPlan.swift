//
//  AnimationPlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct AnimationPlan: Equatable, Sendable {
    // MARK: - Property
    static let none = AnimationPlan(entrance: nil, loop: nil, exit: nil)

    let entrance: PresetSpan?
    let loop: PresetSpan?
    let exit: PresetSpan?

    var isEmpty: Bool {
        entrance == nil && loop == nil && exit == nil
    }

    // MARK: - Initializer
    init(
        entrance: PresetSpan?,
        loop: PresetSpan?,
        exit: PresetSpan?
    ) {
        self.entrance = entrance
        self.loop = loop
        self.exit = exit
    }

    // MARK: - Public
    // MARK: - Private
}
