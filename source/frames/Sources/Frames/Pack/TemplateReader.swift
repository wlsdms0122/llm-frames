//
//  TemplateReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Reads a template from the document it is written in, checked against its parameter types with the media kinds it
// is given.
struct TemplateReader: Sendable {
    // MARK: - Property
    private let checker: KeyChecker

    // MARK: - Initializer
    init(mediaKinds: any MediaKindProvider) {
        self.checker = KeyChecker(mediaKinds: mediaKinds)
    }

    // MARK: - Public
    // `place` is where the template is written.
    func template(
        from document: JSONValue,
        place: Place
    ) throws -> Template {
        let references = try checker.check(template: document, place: place)
        let parameters = (document.objectValue?["params"]?.objectValue?.members ?? []).compactMap { member in
            parameter(member.key, member.value.objectValue ?? JSONObject())
        }

        return Template(
            document: document,
            place: place,
            parameters: parameters,
            references: references
        )
    }

    // MARK: - Private
    private func parameter(
        _ name: String,
        _ declaration: JSONObject
    ) -> TemplateParameter? {
        guard let type = declaration["type"]?.stringValue.flatMap(ParameterType.init(rawValue:)) else { return nil }

        return TemplateParameter(
            name: name,
            type: type,
            defaultValue: declaration["default"],
            options: declaration["options"]?.arrayValue?.compactMap(\.stringValue) ?? []
        )
    }
}
