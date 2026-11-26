//
//  ProcessMemoryMeter.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

import Darwin

// Reads this process's physical footprint and the kernel's largest footprint of it over its life from `task_info`
// with `TASK_VM_INFO`, the footprint `footprint` and Activity Monitor show. It counts the IOSurfaces the process makes
// and not those the decoding service makes and the process maps, which the system charges to the service.
package struct ProcessMemoryMeter: MemoryMeter {
    // MARK: - Property
    // MARK: - Initializer
    package init() {}

    // MARK: - Public
    package func read() -> MemoryReading {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { words in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), words, &count)
            }
        }
        // The process's own task with a flavor and size the system defines is always readable.
        precondition(result == KERN_SUCCESS, "task_info of the process failed: \(result)")

        return MemoryReading(
            footprint: Int(info.phys_footprint),
            peak: Int(info.ledger_phys_footprint_peak),
            time: .now
        )
    }

    // MARK: - Private
}
