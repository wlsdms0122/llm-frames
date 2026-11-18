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
    case list(ValueType)
    case map(ValueType, kind: String)
    case object(ObjectTable)
    case oneOf([ValueType])
    case area
    case crop
    case margin
    case media
    case document
    case clips(ClipPlace)
    case parameters
    case argument
    case filterOperation
}
