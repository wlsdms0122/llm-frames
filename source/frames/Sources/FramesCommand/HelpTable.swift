//
//  HelpTable.swift
//  FramesCommand
//
//  Created by JSilver on 11/19/26.
//

// Help rows as lines, each term indented and padded so the descriptions start in one column.
struct HelpTable: Sendable {
    // MARK: - Property
    private let rows: [HelpRow]

    var text: String {
        let width = (rows.map(\.term.count).max() ?? 0) + 2

        return rows
            .map { row in
                "  " + row.term + String(repeating: " ", count: width - row.term.count) + row.description + "\n"
            }
            .joined()
    }

    // MARK: - Initializer
    init(rows: [HelpRow]) {
        self.rows = rows
    }

    // MARK: - Public
    // MARK: - Private
}
