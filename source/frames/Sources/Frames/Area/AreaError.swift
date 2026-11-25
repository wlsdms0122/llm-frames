//
//  AreaError.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

enum AreaError: Error, Equatable, CustomStringConvertible, Sendable {
    case clipAreaInPicture(place: Place, kind: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .clipAreaInPicture(place, kind):
            "\(place) (\(kind)): a clip area is the box of another clip in the space a clip is drawn in, so it is "
                + "not allowed in a crop, a track target or the mask of a media clip, a title, a storyline clip or a "
                + "shape placed by width and height, which are in the clip's own media or box"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
