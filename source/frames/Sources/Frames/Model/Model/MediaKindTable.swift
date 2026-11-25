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

    // A pack is there where the table holds media or a template in it, and holds the names of the kind it gives.
    func unknown(
        _ kind: ReferenceKind,
        named name: String
    ) -> UnknownReference {
        let all = Set(kinds.keys).union(pageCounts.keys).union(templates)
        let held = kind == .template ? templates : Set(kinds.keys).union(pageCounts.keys)
        let packs = Set(all.compactMap { name -> String? in
            guard case let .pack(pack, _)? = PackReference(name) else { return nil }

            return pack
        })

        return UnknownReference(kind: kind, name: name, packs: { packs.sorted() }) { pack in
            packs.contains(pack) ? held.filter { $0.hasPrefix("\(pack)/") }.sorted() : nil
        }
    }

    // MARK: - Private
}
