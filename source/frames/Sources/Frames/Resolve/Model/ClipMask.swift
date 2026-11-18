//
//  ClipMask.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// One mask as written (FRAMES-11), its keys checked for its shape. `index` is its place in the list written, nil for a
// mask written alone. `radius` is a rect's, in the mask's coordinate space, and `feather` a theme length, not yet
// scaled.
struct ClipMask: Equatable, Sendable {
    // MARK: - Property
    let index: Int?
    let shape: ShapeKind
    let geometry: MaskGeometryForm
    let radius: Double
    let feather: Double
    let isInverted: Bool
    let mode: MaskMode

    // MARK: - Initializer
    init(
        index: Int? = nil,
        shape: ShapeKind,
        geometry: MaskGeometryForm,
        radius: Double = 0,
        feather: Double = 0,
        isInverted: Bool = false,
        mode: MaskMode = .add
    ) {
        self.index = index
        self.shape = shape
        self.geometry = geometry
        self.radius = radius
        self.feather = feather
        self.isInverted = isInverted
        self.mode = mode
    }

    // A mask that passed the key tables.
    init?(
        value: JSONValue,
        index: Int?
    ) {
        guard
            let object = value.objectValue,
            let shape = object["shape"]?.stringValue.flatMap(ShapeKind.init(rawValue:)),
            let geometry = Self.geometry(of: object)
        else {
            return nil
        }

        self.init(
            index: index,
            shape: shape,
            geometry: geometry,
            radius: object["radius"]?.numberValue ?? 0,
            feather: object["feather"]?.numberValue ?? 0,
            isInverted: object["invert"]?.boolValue ?? false,
            mode: object["mode"]?.stringValue.flatMap(MaskMode.init(rawValue:)) ?? .add
        )
    }

    // MARK: - Public
    // A mask or a list of them as written, each with its index in the list.
    static func masks(in value: JSONValue) -> [ClipMask]? {
        guard let elements = value.arrayValue else { return ClipMask(value: value, index: nil).map { [$0] } }

        return elements.enumerated().compactMap { index, element in ClipMask(value: element, index: index) }
    }

    // MARK: - Private
    private static func geometry(of object: JSONObject) -> MaskGeometryForm? {
        if let points = object["points"]?.arrayValue {
            return .points(points.compactMap(PositionForm.init(value:)))
        }
        if let area = object["area"].flatMap(AreaForm.init(value:)) {
            return .area(area)
        }
        guard
            let width = object["width"]?.numberValue,
            let height = object["height"]?.numberValue,
            let position = object["position"].flatMap(PositionForm.init(value:))
        else {
            return nil
        }

        return .box(width: width, height: height, position: position)
    }
}
