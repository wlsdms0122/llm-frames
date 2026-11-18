//
//  DocumentScope.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct DocumentScope: Sendable {
    // MARK: - Property
    let owner: ParameterOwner
    var parameters: [String: JSONObject]
    var usedParameters: Set<String>
    var references: [ParameterReference]
    var identifiers: [String: Place]

    // MARK: - Initializer
    init(
        owner: ParameterOwner = .template,
        parameters: [String: JSONObject] = [:]
    ) {
        self.owner = owner
        self.parameters = parameters
        self.usedParameters = []
        self.references = []
        self.identifiers = [:]
    }

    // MARK: - Public
    // MARK: - Private
}
