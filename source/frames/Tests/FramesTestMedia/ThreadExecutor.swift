//
//  ThreadExecutor.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/26/26.
//

import Foundation

// Runs the jobs of the tasks that prefer it, one at a time in the order they come, on a thread it makes, until it is
// stopped and has run every job it was given.
@available(macOS 15.0, *)
package final class ThreadExecutor: TaskExecutor, @unchecked Sendable {
    // MARK: - Property
    private let condition = NSCondition()
    private var jobs: [UnownedJob] = []
    private var isStopped = false

    // MARK: - Initializer
    package init() {
        Thread { [self] in run() }.start()
    }

    // MARK: - Public
    package func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        condition.withLock {
            jobs.append(job)
            condition.signal()
        }
    }

    // Ends the thread once it has run the jobs given before.
    package func stop() {
        condition.withLock {
            isStopped = true
            condition.signal()
        }
    }

    // MARK: - Private
    private func run() {
        while let job = next() {
            job.runSynchronously(on: asUnownedTaskExecutor())
        }
    }

    // The next job, waited for, or nil once the executor is stopped and every job is run.
    private func next() -> UnownedJob? {
        condition.withLock {
            while jobs.isEmpty, !isStopped {
                condition.wait()
            }

            return jobs.isEmpty ? nil : jobs.removeFirst()
        }
    }
}
