//
//  MetalPictureConverter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

import CoreGraphics
import CoreVideo
import Foundation
import Frames
import IOSurface
import Metal
import os

// Takes a decoded frame's R'G'B' half floats to working values on the GPU, by `WorkingKernelSource`, into a new
// surface (FRAMES-21 Pictures), once per frame. It runs the steps of a conversion that `ConversionSteps` names other
// than `formulas`, from a pixel buffer whose pixels map onto the displayed picture's one to one. Each conversion is
// run whole before the surface is given. The Metal device, its queue and the pipeline are used from any thread, and
// the texture cache and the decode tables under a lock.
final class MetalPictureConverter: @unchecked Sendable {
    // MARK: - Property
    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let pipeline: any MTLComputePipelineState
    private let textureCache: OSAllocatedUnfairLock<CVMetalTextureCache>
    private let decodeTables = OSAllocatedUnfairLock<[TransferFunction: any MTLBuffer]>(uncheckedState: [:])
    // The table bound where the steps decode by none.
    private let emptyTable: any MTLBuffer
    private let surfaces = SurfacePool()

    // MARK: - Initializer
    // Nil on a machine with no Metal device.
    init?() {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let emptyTable = device.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared)
        else {
            return nil
        }

        let options = MTLCompileOptions()
        if #available(macOS 15.0, *) {
            options.mathMode = .safe
        } else {
            options.fastMathEnabled = false
        }
        var cache: CVMetalTextureCache?
        guard
            let library = try? device.makeLibrary(source: WorkingKernelSource.text, options: options),
            let function = library.makeFunction(name: "working"),
            let pipeline = try? device.makeComputePipelineState(function: function),
            CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess,
            let cache
        else {
            return nil
        }

        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.textureCache = OSAllocatedUnfairLock(uncheckedState: cache)
        self.emptyTable = emptyTable
    }

    // MARK: - Public
    // The working values of `buffer`, a `kCVPixelFormatType_64RGBAHalf` buffer of `storedSize` pixels, displayed at
    // `displaySize` by `transform`, top left origin, by `steps`. Nil where the steps are `formulas`, the buffer is of
    // another size or format, the transform is no whole-pixel turn or flip, or Metal does not run the conversion.
    func picture(
        from buffer: CVPixelBuffer,
        storedSize: CGSize,
        displaySize: Size,
        transform: CGAffineTransform,
        steps: ConversionSteps
    ) -> PictureSurface? {
        let width = Int(displaySize.width)
        let height = Int(displaySize.height)
        guard
            CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_64RGBAHalf,
            CVPixelBufferGetWidth(buffer) == Int(storedSize.width),
            CVPixelBufferGetHeight(buffer) == Int(storedSize.height),
            Self.isWholePixelMap(transform),
            let (placement, matrix, table) = arguments(of: steps, transform: transform),
            let surface = surfaces.surface(width: width, height: height),
            let output = device.makeTexture(
                descriptor: Self.descriptor(width: width, height: height, usage: .shaderWrite),
                iosurface: surface.surface,
                plane: 0
            ),
            let stored = texture(of: buffer)
        else {
            return nil
        }

        // The picture counts the surface in use before the lock it was taken under is left, so no other conversion
        // takes it.
        let picture = surface.picture
        guard
            let commands = queue.makeCommandBuffer(),
            let encoder = commands.makeComputeCommandEncoder()
        else {
            return nil
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(CVMetalTextureGetTexture(stored), index: 0)
        encoder.setTexture(output, index: 1)
        placement.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 0) }
        matrix.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 1) }
        encoder.setBuffer(table, offset: 0, index: 2)
        let group = MTLSize(width: 16, height: 16, depth: 1)
        encoder.dispatchThreadgroups(
            MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1),
            threadsPerThreadgroup: group
        )
        encoder.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()
        withExtendedLifetime(stored) {}
        guard commands.status == .completed else { return nil }

        return picture
    }

    // MARK: - Private
    // A turn by a multiple of 90 degrees or a flip, moved by whole pixels, which carries pixel centres onto pixel
    // centres.
    private static func isWholePixelMap(_ transform: CGAffineTransform) -> Bool {
        let entries = [transform.a, transform.b, transform.c, transform.d]
        guard entries.allSatisfy({ [-1, 0, 1].contains($0) }) else { return false }
        guard abs(transform.a) + abs(transform.b) == 1, abs(transform.c) + abs(transform.d) == 1 else { return false }

        return transform.tx == transform.tx.rounded() && transform.ty == transform.ty.rounded()
    }

    // The kernel's placement, with the steps it runs, its matrix as three columns of four floats, and its decode table:
    // nil for `formulas`.
    private func arguments(
        of steps: ConversionSteps,
        transform: CGAffineTransform
    ) -> (placement: [Float], matrix: [Float], table: any MTLBuffer)? {
        let inverse = transform.inverted()
        let placement = { (steps: UInt32) -> [Float] in
            [
                Float(inverse.a), Float(inverse.b), Float(inverse.c), Float(inverse.d),
                Float(inverse.tx), Float(inverse.ty), Float(bitPattern: steps), 0
            ]
        }

        switch steps {
        case .identity:
            return (placement(0), Self.columns(of: .identity), emptyTable)

        case let .decodeMatrixEncode(decodeTable, toLinearSRGB):
            guard let table = buffer(of: decodeTable) else { return nil }

            return (placement(1), Self.columns(of: toLinearSRGB), table)

        case .formulas:
            return nil
        }
    }

    private static func columns(of matrix: ColorMatrix) -> [Float] {
        (0..<3).flatMap { column in (0..<3).map { Float(matrix.rows[$0][column]) } + [0] }
    }

    // The table on the GPU, as single precision floats, made once for each transfer.
    private func buffer(of table: TransferDecodeTable) -> (any MTLBuffer)? {
        decodeTables.withLockUnchecked { tables in
            if let buffer = tables[table.transfer] { return buffer }
            let values = table.values.map(Float.init)
            let buffer = values.withUnsafeBytes {
                device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
            }
            tables[table.transfer] = buffer

            return buffer
        }
    }

    private func texture(of buffer: CVPixelBuffer) -> CVMetalTexture? {
        textureCache.withLockUnchecked { cache in
            var texture: CVMetalTexture?
            let status = CVMetalTextureCacheCreateTextureFromImage(
                nil,
                cache,
                buffer,
                nil,
                .rgba16Float,
                CVPixelBufferGetWidth(buffer),
                CVPixelBufferGetHeight(buffer),
                0,
                &texture
            )

            CVMetalTextureCacheFlush(cache, 0)

            return status == kCVReturnSuccess ? texture : nil
        }
    }

    private static func descriptor(
        width: Int,
        height: Int,
        usage: MTLTextureUsage
    ) -> MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage
        descriptor.storageMode = .shared

        return descriptor
    }
}
