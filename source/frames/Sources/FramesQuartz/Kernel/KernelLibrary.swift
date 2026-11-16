//
//  KernelLibrary.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreImage

// The colour kernels of the blend and filter sources, compiled together as one Core Image Metal library and handed
// out by function name.
final class KernelLibrary: Sendable {
    // MARK: - Property
    // Compiling takes about half a second, so the process compiles the library once.
    static let shared = Result { try KernelLibrary() }

    private static let header = """
        #include <CoreImage/CoreImage.h>
        using namespace metal;
        """

    private let kernels: [String: CIColorKernel]

    // MARK: - Initializer
    init() throws {
        let source = """
            \(Self.header)
            extern "C" { namespace coreimage {
            \(BlendKernelSource.text)
            \(FilterKernelSource.text)
            } }
            """
        let compiled = try CIKernel.kernels(withMetalString: source).compactMap { $0 as? CIColorKernel }

        self.kernels = Dictionary(uniqueKeysWithValues: compiled.map { ($0.name, $0) })
    }

    // MARK: - Public
    func colorKernel(named name: String) throws -> CIColorKernel {
        guard let kernel = kernels[name] else { throw QuartzError.unknownKernel(name: name) }

        return kernel
    }

    // MARK: - Private
}
