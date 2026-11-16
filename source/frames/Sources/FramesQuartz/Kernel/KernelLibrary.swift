//
//  KernelLibrary.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreImage
import Foundation

// The colour kernels of the blend, matte and filter sources, handed out by function name. Core Image runs, for every
// kernel of one Metal library taking as many images, the one of them applied first, so each kernel is compiled into a
// library of its own: the sources with every other function made plain. A kernel is compiled the first time it is
// asked for, in about half a second, and kept for the process.
final class KernelLibrary: @unchecked Sendable {
    // MARK: - Property
    static let shared = Result<KernelLibrary, any Error>.success(KernelLibrary())

    private static let header = """
        #include <CoreImage/CoreImage.h>
        using namespace metal;
        extern "C" { namespace coreimage {
        """
    private static let footer = """
        } }
        """
    private static let attribute = "[[stitchable]] "

    private let source: String
    private let lock = NSLock()
    private var kernels: [String: CIColorKernel] = [:]

    // MARK: - Initializer
    init() {
        source = [BlendKernelSource.text, MatteKernelSource.text, FilterKernelSource.text].joined(separator: "\n")
    }

    // MARK: - Public
    func colorKernel(named name: String) throws -> CIColorKernel {
        lock.lock()
        defer { lock.unlock() }

        if let kernel = kernels[name] { return kernel }

        let declaration = "\(Self.attribute)float4 \(name)("
        let plain = "float4 \(name)("
        guard source.contains(declaration) else { throw QuartzError.unknownKernel(name: name) }

        let alone = source
            .replacingOccurrences(of: declaration, with: plain)
            .replacingOccurrences(of: Self.attribute, with: "inline ")
            .replacingOccurrences(of: plain, with: declaration)
        let compiled = try CIKernel.kernels(withMetalString: [Self.header, alone, Self.footer].joined(separator: "\n"))
        guard let kernel = compiled.first(where: { $0.name == name }) as? CIColorKernel else {
            throw QuartzError.unknownKernel(name: name)
        }
        kernels[name] = kernel

        return kernel
    }

    // MARK: - Private
}
