//
//  FaceMatcher.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The font matching of CSS Fonts 4 over one family's faces, with `font-stretch: normal`. Faces equal on every step
// are told apart by name, so a family gives the same face whatever order its faces are listed in.
struct FaceMatcher: Sendable {
    // MARK: - Property
    private static let normalWidth = 5

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func face(
        among faces: [FontFace],
        weight: FontWeight,
        italic: Bool
    ) -> FontFace? {
        let styles: [FontStyle] = italic ? [.italic, .oblique, .upright] : [.upright, .oblique, .italic]
        let byWidth = narrowed(faces, by: \.width, preferring: widthOrder(of: faces.map(\.width)))
        let byStyle = narrowed(byWidth, by: \.style, preferring: styles)
        let weights = weightOrder(of: byStyle.map(\.weight.value), wanted: weight.value)
        let byWeight = narrowed(byStyle, by: \.weight.value, preferring: weights)

        return byWeight.min { $0.name < $1.name }
    }

    // MARK: - Private
    // The faces whose key is the first in `order` any face has.
    private func narrowed<Key: Equatable>(
        _ faces: [FontFace],
        by key: (FontFace) -> Key,
        preferring order: [Key]
    ) -> [FontFace] {
        for wanted in order {
            let matching = faces.filter { key($0) == wanted }
            if !matching.isEmpty {
                return matching
            }
        }

        return faces
    }

    // Normal width, else the narrower widths from the widest down, else the wider ones from the narrowest up.
    private func widthOrder(of widths: [Int]) -> [Int] {
        let narrower = Set(widths.filter { $0 < Self.normalWidth }).sorted(by: >)
        let wider = Set(widths.filter { $0 > Self.normalWidth }).sorted()

        return [Self.normalWidth] + narrower + wider
    }

    // From 400 to 500 the nearest from the weight up to 500, else the nearest below, else the nearest above 500. A
    // lighter weight the nearest at or below it, else the nearest above; a heavier one the nearest at or above it,
    // else the nearest below.
    private func weightOrder(
        of weights: [Int],
        wanted: Int
    ) -> [Int] {
        let available = Set(weights)
        let atOrAbove = available.filter { $0 >= wanted }.sorted()
        let atOrBelow = available.filter { $0 <= wanted }.sorted(by: >)
        let below = atOrBelow.filter { $0 < wanted }
        let above = atOrAbove.filter { $0 > wanted }

        if (400...500).contains(wanted) {
            return atOrAbove.filter { $0 <= 500 } + below + atOrAbove.filter { $0 > 500 }
        } else if wanted < 400 {
            return atOrBelow + above
        } else {
            return atOrAbove + below
        }
    }
}
