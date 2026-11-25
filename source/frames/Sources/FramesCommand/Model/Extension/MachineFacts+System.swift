//
//  MachineFacts+System.swift
//  FramesCommand
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import Frames

extension MachineFacts {
    // MARK: - Property
    // The machine frames runs on: the processor's name, which macOS gives as `machdep.cpu.brand_string`, its logical
    // cores, and the operating system's version.
    static var current: MachineFacts {
        let version = ProcessInfo.processInfo.operatingSystemVersion

        return MachineFacts(
            chip: brandString(),
            cores: ProcessInfo.processInfo.processorCount,
            operatingSystem: "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        )
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private static func brandString() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0)

        return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
