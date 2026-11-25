//
//  ValueType.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

indirect enum ValueType: Equatable, Sendable {
    case anyValue
    case anyObject
    case exactly(JSONValue)
    case bool
    case number(NumberDomain)
    case integer
    case nonNegativeInteger
    case positiveInteger
    case text
    case name
    case color
    // A colour written out, a hex colour or a `color()` value, and not a theme colour's name.
    case unnamedColor
    case identifier
    case ease
    case literal([String])
    // A list of that many numbers, each in the domain.
    case numbers(Int, NumberDomain)
    // A path's vertices: a list of at least two, each a point as `position` takes it or a vertex object, whose
    // `vertex` a keyframe may leave out (`PathKeyTable`).
    case points(isKeyframed: Bool)
    // A list of four points, each as `position` takes it: a quadrilateral's corners, top left, top right, bottom right
    // and bottom left.
    case quad
    // A list of four points `[x, y]` of numbers: a quadrilateral in media pixels, as track data writes it.
    case mediaQuad
    // A dash pattern: a list of at least one length, each 0 or more, not all 0. A pattern of zeros would draw the stroke
    // whole, where the patterns beside it draw fine dots. In a keyframe a length may be `null`, and lengths that are all
    // 0 with the merged value's in place of each `null` stop when the look is merged.
    case dash(isKeyframed: Bool)
    // A gradient's stops: a list of at least two `[offset, colour]`, each offset from 0 to 1 and at least the one
    // before it. In a keyframe an offset or a colour may be `null` and the offsets may be in any order, since sampling
    // raises each offset to the one before it.
    case stops(isKeyframed: Bool)
    case list(ValueType)
    case map(ValueType, kind: String)
    case object(ObjectTable)
    // An object of one of the kinds of the table, which its `kind` names.
    case kinds(KindTable)
    case oneOf([ValueType])
    case area
    case crop
    // A mask, or a list of at least one mask, each taking the keys of its shape.
    case masks
    // A title's text: a string, or a list of at least one run.
    case runs
    case margin
    case media
    case document
    case clips(ClipPlace)
    // A `params` object, each parameter checked by the table of its owner.
    case parameters(ObjectTable)
    case argument
    // An argument a preset choice passes, whose type is the preset's to say. It is a number, a colour or an ease,
    // and a template's parameter stands for it.
    case presetArgument
    // A preset name, `{preset, args}`, or a list of at least one of those without `"none"`.
    case filterChoice
    // An audio preset name, `{preset, args, mix}`, an audio op, or a list of at least one of those.
    case audioFilterChoice
    case filterOperation
    case audioOperation
    // A value its leaf's named check takes.
    case leaf(LeafCheck)
}
