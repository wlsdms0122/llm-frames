//
//  FaceMatcherTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

@Suite("FaceMatcher Tests")
struct FaceMatcherTests {
    // MARK: - Property
    private let sut = FaceMatcher()

    // MARK: - Initializer
    // MARK: - Test
    @Test("normal width comes first, then the narrower widths from the widest down, then the wider from the narrowest up")
    func narrowsByWidth() {
        // Given
        let narrow = [face(400, width: 2), face(400, width: 3), face(400, width: 7)]
        let wide = [face(400, width: 7), face(400, width: 9)]

        // When
        let normal = sut.face(among: narrow + [face(700)], weight: .regular, italic: false)
        let narrower = sut.face(among: narrow, weight: .regular, italic: false)
        let wider = sut.face(among: wide, weight: .regular, italic: false)

        // Then
        #expect(normal == face(700))
        #expect(narrower == face(400, width: 3))
        #expect(wider == face(400, width: 7))
    }

    @Test(
        "italic takes italic, else oblique, else upright; upright takes upright, else oblique, else italic",
        arguments: [
            ([FontStyle.italic, .oblique, .upright], true, FontStyle.italic),
            ([.oblique, .upright], true, .oblique),
            ([.upright], true, .upright),
            ([.italic, .oblique, .upright], false, .upright),
            ([.italic, .oblique], false, .oblique),
            ([.italic], false, .italic)
        ]
    )
    func narrowsByStyle(styles: [FontStyle], italic: Bool, chosen: FontStyle) {
        // Given
        let faces = styles.map { face(400, style: $0) }

        // When
        let face = sut.face(among: faces, weight: .regular, italic: italic)

        // Then
        #expect(face?.style == chosen)
    }

    @Test(
        "a weight from 400 to 500 looks up to 500, then below, then above 500; a lighter one down then up; a heavier one up then down",
        arguments: [
            ([300, 500, 600], 400, 500),
            ([300, 600], 400, 300),
            ([600, 700], 450, 600),
            ([200, 400], 300, 200),
            ([400, 500], 300, 400),
            ([600, 800], 700, 800),
            ([400, 600], 700, 600)
        ]
    )
    func narrowsByWeight(weights: [Int], wanted: Int, chosen: Int) {
        // Given
        let faces = weights.map { face($0) }

        // When
        let face = sut.face(among: faces, weight: FontWeight(wanted), italic: false)

        // Then
        #expect(face?.weight == FontWeight(chosen))
    }

    @Test("faces equal on every step are told apart by name, whatever their order")
    func breaksTiesByName() {
        // Given
        let faces = [face(400, name: "B"), face(400, name: "A")]

        // When
        let face = sut.face(among: faces, weight: .regular, italic: false)
        let reversed = sut.face(among: faces.reversed(), weight: .regular, italic: false)

        // Then
        #expect(face?.name == "A")
        #expect(reversed?.name == "A")
    }

    @Test("a family without faces gives none")
    func findsNoFace() {
        // Given
        let faces: [FontFace] = []

        // When
        let face = sut.face(among: faces, weight: .bold, italic: true)

        // Then
        #expect(face == nil)
    }

    // MARK: - Private
    private func face(
        _ weight: Int,
        width: Int = 5,
        style: FontStyle = .upright,
        name: String? = nil
    ) -> FontFace {
        let face = ShaperTable.face("Family", FontWeight(weight), style: style, width: width)
        guard let name else { return face }

        return FontFace(
            file: face.file,
            name: name,
            weight: face.weight,
            width: face.width,
            style: face.style,
            ascent: face.ascent,
            descent: face.descent,
            underlineOffset: face.underlineOffset,
            underlineThickness: face.underlineThickness
        )
    }
}
