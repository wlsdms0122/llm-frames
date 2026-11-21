//
//  MediaKindTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The probed kind of each media file and the page count of each PDF, keyed by the reference written in the document,
// and the names of the templates that are there.
struct MediaKindTable: MediaKindProvider {
    // MARK: - Property
    let kinds: [String: MediaKind]
    let pageCounts: [String: Int]
    let templates: Set<String>

    // MARK: - Initializer
    init(
        _ kinds: [String: MediaKind] = [:],
        pageCounts: [String: Int] = [:],
        templates: Set<String> = []
    ) {
        self.kinds = kinds
        self.pageCounts = pageCounts
        self.templates = templates
    }

    // MARK: - Public
    func mediaKind(of reference: String) -> ProbedKind? {
        if let pageCount = pageCounts[reference] { return .pdf(pageCount: pageCount) }

        return kinds[reference].map(ProbedKind.media)
    }

    func hasTemplate(named name: String) -> Bool {
        templates.contains(name)
    }

    // MARK: - Private
}
