//
//  ChromaSampling.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/26/26.
//

// How many luma samples a Y'CbCr stream's chroma sample covers: two across and two down at 4:2:0, two across at
// 4:2:2, one at 4:4:4.
enum ChromaSampling: Equatable, Sendable {
    case fourTwoZero
    case fourTwoTwo
    case fourFourFour

    // MARK: - Property
    var horizontal: Int {
        self == .fourFourFour ? 1 : 2
    }

    var vertical: Int {
        self == .fourTwoZero ? 2 : 1
    }

    var name: String {
        switch self {
        case .fourTwoZero:
            "4:2:0"

        case .fourTwoTwo:
            "4:2:2"

        case .fourFourFour:
            "4:4:4"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
