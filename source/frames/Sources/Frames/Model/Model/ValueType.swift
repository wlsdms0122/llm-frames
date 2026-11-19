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
    case number
    case positiveNumber
    case nonNegativeNumber
    // A number from 0 to 1.
    case fraction
    // A number from -1 to 1.
    case signedFraction
    // A number greater than -1 and less than 1.
    case openSignedFraction
    case integer
    case nonNegativeInteger
    case positiveInteger
    case text
    case name
    case color
    case hexColor
    case identifier
    case ease
    case literal([String])
    case numbers(Int)
    // A list of that many numbers, each from 0 to 1.
    case fractions(Int)
    // A list of at least two points, each as `position` takes it.
    case points
    // A dash pattern: a list of at least one length, each 0 or more, not all 0. A pattern of zeros would draw the stroke
    // whole, where the patterns beside it draw fine dots.
    case dash
    // A gradient's stops: a list of at least two `[offset, colour]`, each offset from 0 to 1 and at least the one
    // before it. In a keyframe an offset or a colour may be `null` and the offsets may be in any order, since sampling
    // raises each offset to the one before it.
    case stops(isKeyframed: Bool)
    case list(ValueType)
    case map(ValueType, kind: String)
    case object(ObjectTable)
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
}
