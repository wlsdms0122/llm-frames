//
//  FilterEntry+Sampled.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A timed filter's entry at one instant, its ops and `mix` sampled.
extension FilterEntry {
    // MARK: - Property
    // MARK: - Initializer
    init(sampled: SampledValue) {
        let operations = if case let .list(elements) = sampled["ops"] { elements } else { [SampledValue]() }
        self.init(operations: operations.compactMap(ResolvedFilterOperation.init(sampled:)), mix: sampled["mix"]?.number ?? 1)
    }

    // MARK: - Public
    // The entries of a timed filter at `time`, none where it is off.
    static func entries(
        of filter: TimedValue,
        at time: SampleTime
    ) -> [FilterEntry] {
        guard case let .list(entries) = filter.sampled(at: time, as: LookStructureTable.resolvedFilter) else { return [] }

        return entries.map(FilterEntry.init(sampled:))
    }

    // MARK: - Private
}
