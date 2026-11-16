//
//  LocationReporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Maps a point of the output at a time back to what drew it, as `locate` prints it: every item of the display list
// whose coverage holds the point, nested lists flattened, topmost first. An item covers what its rectangle, cut by its
// masks, reveals and the pictures holding it, covers; rounded corners, trims, mattes and transparent pixels are not
// told apart.
package struct LocationReporter: Sendable {
    // MARK: - Property
    private let evaluator = Evaluator()
    private let flattener = DisplayListFlattener()

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    // `point` is in output pixels.
    package func report(
        of document: ResolvedDocument,
        at time: Double,
        point: Point
    ) -> LocationReport {
        report(of: evaluator.displayList(of: document, at: time), point: point)
    }

    func report(
        of list: DisplayList,
        point: Point
    ) -> LocationReport {
        LocationReport(hits: flattener.items(of: list).reversed()
            .filter { $0.coverage.contains(point) }
            .map { LocationHit($0, point: point) }
        )
    }

    // MARK: - Private
}
