//
//  TrackTarget.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What `track` follows: the clip's own area or crop (`true`), or an area it names.
enum TrackTarget: Equatable, Sendable {
    case own
    case area(AreaForm)

    // MARK: - Property
    // MARK: - Initializer
    init?(value: JSONValue) {
        if value == .bool(true) {
            self = .own
            return
        }
        guard let area = AreaForm(value: value) else { return nil }

        self = .area(area)
    }

    // MARK: - Public
    // MARK: - Private
}
