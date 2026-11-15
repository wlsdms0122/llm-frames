//
//  PlaceComponent.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum PlaceComponent: Hashable, Sendable {
    case key(String)
    case index(Int, id: String?)
}
