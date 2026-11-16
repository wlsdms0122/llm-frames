//
//  DocumentScope.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct DocumentScope: Sendable {
    // MARK: - Property
    var parameters: [String: JSONObject]
    var usedParameters: Set<String>
    var references: [ParameterReference]
    var identifiers: [String: Place]

    // MARK: - Initializer
    init(parameters: [String: JSONObject] = [:]) {
        self.parameters = parameters
        self.usedParameters = []
        self.references = []
        self.identifiers = [:]
    }

    // MARK: - Public
    // MARK: - Private
}
