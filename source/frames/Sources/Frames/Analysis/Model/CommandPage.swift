//
//  CommandPage.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// What a command reads of a file by its `--page` (FRAMES-23): the page numbered `number` of a PDF, from 1, a PDF of
// more than one page with no page named, or a file that is no PDF and names no page, by its probe.
enum CommandPage: Equatable, Sendable {
    case page(number: Int)
    case unnamed(pageCount: Int)
    case media(ProbedMedia)
}
