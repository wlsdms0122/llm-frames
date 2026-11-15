//
//  DocumentPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve decided for a document: a sequence's plan, or the plan of an image or layout document.
enum DocumentPlan: Equatable, Sendable {
    case sequence(SequencePlan)
    case picture(PicturePlan)

    // MARK: - Property
    // The size of the picture the document draws.
    var size: Size {
        switch self {
        case let .sequence(plan):
            plan.format.size

        case let .picture(plan):
            plan.size
        }
    }

    var sequence: SequencePlan? {
        guard case let .sequence(plan) = self else { return nil }

        return plan
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
