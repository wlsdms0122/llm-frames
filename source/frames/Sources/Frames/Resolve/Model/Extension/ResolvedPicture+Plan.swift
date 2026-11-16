//
//  ResolvedPicture+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve decided for an image or layout document, with every file its steps draw pinned.
extension ResolvedPicture {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: PicturePlan,
        hashes: any FileHashProvider
    ) throws {
        self.init(
            kind: plan.kind,
            size: plan.size,
            steps: try plan.steps.map { try ResolvedDrawingStep(step: $0, hashes: hashes) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
