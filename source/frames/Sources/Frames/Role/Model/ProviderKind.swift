//
//  ProviderKind.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

enum ProviderKind: Equatable, Sendable {
    case shaping
    case tracker
    case ocr

    // MARK: - Property
    var label: String {
        switch self {
        case .shaping:
            "shaping provider"

        case .tracker:
            "tracker"

        case .ocr:
            "OCR provider"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
