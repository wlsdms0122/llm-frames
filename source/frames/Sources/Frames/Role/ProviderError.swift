//
//  ProviderError.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// `place` is where the document asked the provider, or the command's option, which has no `kind`. `picture` is nil
// for the shaping provider, which reads none.
enum ProviderError: Error, Equatable, CustomStringConvertible, Sendable {
    case failed(
        provider: ProviderKind,
        place: Place,
        kind: String?,
        picture: ProviderPicture?,
        message: String
    )

    // MARK: - Property
    var description: String {
        switch self {
        case let .failed(provider, place, kind, picture, message):
            let asker = kind.map { "\(place) (\($0))" } ?? place.description
            let picture = picture.map { " on \(quoted($0.media)) at media second \(number($0.mediaTime))" } ?? ""

            return "\(asker): the \(provider.label) failed\(picture): \(message)"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }

    private func number(_ number: Double) -> String {
        JSONValue.number(number).written
    }
}
