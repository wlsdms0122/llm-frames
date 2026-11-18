//
//  Parameter.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A published parameter of a template or a preset. `options` are a choice's, and empty for any other type.
struct Parameter: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let type: ParameterType
    let defaultValue: JSONValue?
    let options: [JSONValue]

    // The value an argument for it is, and its default: a choice's one of its options.
    var valueType: ValueType {
        switch type {
        case .text:
            .text

        case .color:
            .color

        case .number:
            .number

        case .choice:
            // Names read best as a list of names, and an option of any other form is matched as written.
            if options.allSatisfy({ $0.stringValue != nil }) {
                .literal(options.compactMap(\.stringValue))
            } else {
                .oneOf(options.map { .exactly($0) })
            }

        case .video, .sequence, .image, .audio:
            .media
        }
    }

    // MARK: - Initializer
    init(
        name: String,
        type: ParameterType,
        defaultValue: JSONValue? = nil,
        options: [JSONValue] = []
    ) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.options = options
    }

    // A declaration that passed its checks, so only one without a known type is nil.
    init?(
        name: String,
        declaration: JSONObject
    ) {
        guard let type = declaration["type"]?.stringValue.flatMap(ParameterType.init(rawValue:)) else { return nil }

        self.init(
            name: name,
            type: type,
            defaultValue: declaration["default"],
            options: declaration["options"]?.arrayValue ?? []
        )
    }

    // MARK: - Public
    // The parameters a template or a preset declares in its `params`, in the order they are written.
    static func declared(in value: JSONValue) -> [Parameter] {
        (value.objectValue?["params"]?.objectValue?.members ?? []).compactMap { member in
            Parameter(name: member.key, declaration: member.value.objectValue ?? JSONObject())
        }
    }

    // MARK: - Private
}
