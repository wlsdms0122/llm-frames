//
//  LeafKind.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A leaf of a keyed value: its form, its domain, whether it is a theme length, which resolve scales to output pixels,
// for a name the names it takes, nil for any, and how it moves between keyframes.
struct LeafKind: Equatable, Sendable {
    // MARK: - Property
    static let name = LeafKind(form: .name)
    static let boolean = LeafKind(form: .boolean)
    static let color = LeafKind(form: .color)
    // A positive number heard by its ratio, as a frequency is, which moves geometrically between keyframes.
    static let ratio = LeafKind(form: .number, domain: .between(0, .infinity), interpolation: .geometric)

    let form: LeafForm
    let domain: LeafDomain
    let isLength: Bool
    let names: [String]?
    let interpolation: LeafInterpolation

    var isTimed: Bool { form.isTimed }

    // MARK: - Initializer
    init(
        form: LeafForm,
        domain: LeafDomain = .any,
        isLength: Bool = false,
        names: [String]? = nil,
        interpolation: LeafInterpolation = .linear
    ) {
        self.form = form
        self.domain = domain
        self.isLength = isLength
        self.names = names
        self.interpolation = interpolation
    }

    // MARK: - Public
    static func name(among names: [String]) -> LeafKind {
        LeafKind(form: .name, names: names)
    }

    static func number(_ domain: LeafDomain = .any) -> LeafKind {
        LeafKind(form: .number, domain: domain)
    }

    static func length(_ domain: LeafDomain = .nonNegative) -> LeafKind {
        LeafKind(form: .number, domain: domain, isLength: true)
    }

    static func lengths(
        count: Int,
        domain: LeafDomain = .any
    ) -> LeafKind {
        LeafKind(form: .numbers(count: count), domain: domain, isLength: true)
    }

    static func numbers(
        count: Int,
        domain: LeafDomain = .any
    ) -> LeafKind {
        LeafKind(form: .numbers(count: count), domain: domain)
    }

    // MARK: - Private
}
