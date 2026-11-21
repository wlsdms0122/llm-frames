//
//  OptionalContentConfiguration.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics

// The default configuration of a document's optional content (ISO 32000-1 8.11.4.3, `/OCProperties /D`) for viewing:
// which optional content groups are on, by its `BaseState` and its `ON` and `OFF` arrays and then its `AS` entries for
// the View event (8.11.4.4), and so whether a group or a membership dictionary (8.11.2.2, by its `VE` expression or
// else its `P` policy) shows the content it marks. A document with no optional content shows everything.
struct OptionalContentConfiguration {
    // MARK: - Property
    private let isOnByDefault: Bool
    private let on: Set<CGPDFDictionaryRef>
    private let off: Set<CGPDFDictionaryRef>

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
        var on = Self.groups(in: configuration, key: "ON")
        var off = Self.groups(in: configuration, key: "OFF")
        for (group, isOn) in Self.viewStates(in: configuration) {
            if isOn {
                on.insert(group)
                off.remove(group)
            } else {
                off.insert(group)
                on.remove(group)
            }
        }
        self.isOnByDefault = base != "OFF"
        self.on = on
        self.off = off
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
    ) -> Set<CGPDFDictionaryRef> {
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(configuration, key, &array), let array else { return [] }

        return Set(dictionaries(in: array))
    }

    // The states the `AS` entries of the View event set, in order: each group an entry lists, by that group's `Usage`
    // in each category the entry names. A category's state is its dictionary's `ViewState`, `PrintState` or
    // `ExportState`; the other categories (`Zoom`, `User`, `Language`, `PageElement`) hold none, so they set nothing.
    private static func viewStates(in configuration: CGPDFDictionaryRef) -> [(CGPDFDictionaryRef, Bool)] {
        var entries: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(configuration, "AS", &entries), let entries else { return [] }

        return dictionaries(in: entries).flatMap { entry -> [(CGPDFDictionaryRef, Bool)] in
            var event: UnsafePointer<CChar>?
            var groups: CGPDFArrayRef?
            var categories: CGPDFArrayRef?
            guard
                CGPDFDictionaryGetName(entry, "Event", &event),
                let event,
                String(cString: event) == "View",
                CGPDFDictionaryGetArray(entry, "OCGs", &groups),
                let groups,
                CGPDFDictionaryGetArray(entry, "Category", &categories),
                let categories
            else { return [] }
            let names = (0..<CGPDFArrayGetCount(categories)).compactMap { index -> String? in
                var name: UnsafePointer<CChar>?
                return CGPDFArrayGetName(categories, index, &name) ? name.map { String(cString: $0) } : nil
            }

            return dictionaries(in: groups).flatMap { group in
                names.compactMap { category in state(of: group, in: category).map { (group, $0) } }
            }
        }
    }

    // Whether `group`'s usage in `category` turns it on, nil where it gives no state there.
    private static func state(
        of group: CGPDFDictionaryRef,
        in category: String
    ) -> Bool? {
        var usage: CGPDFDictionaryRef?
        var entry: CGPDFDictionaryRef?
        var state: UnsafePointer<CChar>?
        guard
            ["View", "Print", "Export"].contains(category),
            CGPDFDictionaryGetDictionary(group, "Usage", &usage),
            let usage,
            CGPDFDictionaryGetDictionary(usage, category, &entry),
            let entry,
            CGPDFDictionaryGetName(entry, "\(category)State", &state),
            let state
        else { return nil }

        switch String(cString: state) {
        case "ON":
            return true

        case "OFF":
            return false

        default:
            return nil
        }
    }

    private static func dictionaries(in array: CGPDFArrayRef) -> [CGPDFDictionaryRef] {
        (0..<CGPDFArrayGetCount(array)).compactMap { index in
            var dictionary: CGPDFDictionaryRef?
            guard CGPDFArrayGetDictionary(array, index, &dictionary), let dictionary else { return nil }

            return dictionary
        }
    }

    private func isOn(_ group: CGPDFDictionaryRef) -> Bool {
        if off.contains(group) { return false }
        if on.contains(group) { return true }

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
        let written = CGPDFDictionaryGetName(membership, "P", &policy) ? policy.map { String(cString: $0) } : nil
        switch written {
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
