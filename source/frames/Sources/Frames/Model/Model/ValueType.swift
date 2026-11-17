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
    case text
    case name
    case color
    case hexColor
    case identifier
    case ease
    case literal([String])
    case numbers(Int)
    case list(ValueType)
    case map(ValueType, kind: String)
    case object(ObjectTable)
    case oneOf([ValueType])
    case area
    case crop
    case media
    case document
    case clips(ClipPlace)
    case parameters
    case argument
    case filterOperation
}
