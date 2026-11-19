//
//  ProviderError.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// `place` is where the document asked the provider, or the command's option, which has no `kind`. A provider that
// reads a picture names its media and media time, and the shaping provider names neither.
enum ProviderError: Error, Equatable, CustomStringConvertible, Sendable {
    case failed(
        provider: ProviderKind,
        place: Place,
        kind: String?,
        media: String?,
        mediaTime: Double?,
        message: String
    )

    // MARK: - Property
    var description: String {
        switch self {
        case let .failed(provider, place, kind, media, mediaTime, message):
            let asker = kind.map { "\(place) (\($0))" } ?? place.description
            let picture = media.map { media in
                " on \(quoted(media))" + (mediaTime.map { " at media second \(number($0))" } ?? "")
            } ?? ""

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
