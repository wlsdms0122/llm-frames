//
//  CoverSource.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What a transition's cover shows: a colour, a media file, or a page of a PDF by its number from 1.
enum CoverSource: Equatable, Sendable {
    case color(String)
    case media(String)
    case page(String, page: Int)
}
