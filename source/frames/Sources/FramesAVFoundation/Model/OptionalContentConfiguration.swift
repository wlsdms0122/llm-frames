//
//  OptionalContentConfiguration.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics

// The default configuration of a document's optional content (ISO 32000-1 8.11.4.3, `/OCProperties /D`): which
// optional content groups are on, by its `BaseState` and its `ON` and `OFF` arrays, and so whether a group or a
// membership dictionary (8.11.2.2, by its `VE` expression or else its `P` policy) shows the content it marks. A
// document with no optional content shows everything.
struct OptionalContentConfiguration {
    // MARK: - Property
    private let isOnByDefault: Bool
    private let on: Set<UnsafeRawPointer>
    private let off: Set<UnsafeRawPointer>

    // MARK: - Initializer
    init(document: CGPDFDocument) {
        var properties: CGPDFDictionaryRef?
        var configuration: CGPDFDictionaryRef?
        guard
            let catalog = document.catalog,
            CGPDFDictionaryGetDictionary(catalog, "OCProperties", &properties),
            let properties,
            CGPDFDictionaryGetDictionary(properties, "D", &configuration),
            let configuration
        else {
            self.isOnByDefault = true
            self.on = []
            self.off = []
            return
        }

        var baseState: UnsafePointer<CChar>?
        let base = CGPDFDictionaryGetName(configuration, "BaseState", &baseState) ? baseState.map { String(cString: $0) } : nil
        self.isOnByDefault = base != "OFF"
        self.on = Self.groups(in: configuration, key: "ON")
        self.off = Self.groups(in: configuration, key: "OFF")
    }

    // MARK: - Public
    // Whether content marked by `dictionary`, a group or a membership dictionary, is shown. Anything else shows it.
    func shows(_ dictionary: CGPDFDictionaryRef) -> Bool {
        var type: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dictionary, "Type", &type), let type else { return true }

        switch String(cString: type) {
        case "OCG":
            return isOn(dictionary)

        case "OCMD":
            var expression: CGPDFArrayRef?
            if CGPDFDictionaryGetArray(dictionary, "VE", &expression), let expression {
                return evaluated(expression)
            }

            return membershipShows(dictionary)

        default:
            return true
        }
    }

    // MARK: - Private
    private static func groups(
        in configuration: CGPDFDictionaryRef,
        key: String
    ) -> Set<UnsafeRawPointer> {
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(configuration, key, &array), let array else { return [] }

        return Set((0..<CGPDFArrayGetCount(array)).compactMap { index in
            var group: CGPDFDictionaryRef?
            guard CGPDFArrayGetDictionary(array, index, &group), let group else { return nil }

            return UnsafeRawPointer(group)
        })
    }

    private func isOn(_ group: CGPDFDictionaryRef) -> Bool {
        let pointer = UnsafeRawPointer(group)
        if off.contains(pointer) { return false }
        if on.contains(pointer) { return true }

        return isOnByDefault
    }

    // `OCGs` by `P`: AnyOn where it writes none.
    private func membershipShows(_ membership: CGPDFDictionaryRef) -> Bool {
        var groups: [CGPDFDictionaryRef] = []
        var single: CGPDFDictionaryRef?
        var array: CGPDFArrayRef?
        if CGPDFDictionaryGetDictionary(membership, "OCGs", &single), let single {
            groups = [single]
        } else if CGPDFDictionaryGetArray(membership, "OCGs", &array), let array {
            groups = (0..<CGPDFArrayGetCount(array)).compactMap { index in
                var group: CGPDFDictionaryRef?
                return CGPDFArrayGetDictionary(array, index, &group) ? group : nil
            }
        }
        guard !groups.isEmpty else { return true }

        var policy: UnsafePointer<CChar>?
        let states = groups.map(isOn)
        switch CGPDFDictionaryGetName(membership, "P", &policy) ? policy.map { String(cString: $0) } : nil {
        case "AllOn":
            return states.allSatisfy { $0 }

        case "AnyOff":
            return states.contains(false)

        case "AllOff":
            return states.allSatisfy { !$0 }

        default:
            return states.contains(true)
        }
    }

    // A visibility expression: a group, or an array of `And`, `Or` or `Not` and its operands.
    private func evaluated(_ expression: CGPDFArrayRef) -> Bool {
        var operation: UnsafePointer<CChar>?
        guard CGPDFArrayGetName(expression, 0, &operation), let operation else { return true }
        let operands = (1..<max(1, CGPDFArrayGetCount(expression))).map { index in
            var group: CGPDFDictionaryRef?
            var nested: CGPDFArrayRef?
            if CGPDFArrayGetDictionary(expression, index, &group), let group { return isOn(group) }
            if CGPDFArrayGetArray(expression, index, &nested), let nested { return evaluated(nested) }

            return true
        }

        switch String(cString: operation) {
        case "And":
            return operands.allSatisfy { $0 }

        case "Or":
            return operands.contains(true)

        case "Not":
            return !(operands.first ?? false)

        default:
            return true
        }
    }
}
