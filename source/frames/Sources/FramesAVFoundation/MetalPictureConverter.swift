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

// Takes a decoded frame, its Y'CbCr or its R'G'B' half floats, to working values on the GPU, by `WorkingKernelSource`,
// into a surface no picture holds (FRAMES-21 Pictures), once per frame. It runs the steps of a conversion that `ConversionSteps` names
// other than `formulas`, from a pixel buffer whose pixels map onto the displayed picture's one to one. Each surface
// keeps the texture the function writes it through, since the GPU maps a surface's memory anew for each texture made on
// it. A decoded buffer is read through textures made on its own surface for its one conversion and let go of with it:
// the decoding service holds a buffer's memory while any texture is made on it, and a texture kept past its buffer keeps
// the buffers of a reader closed for a turn after the reader is gone (FRAMES-30). Each conversion is run whole before
// the surface is given. The Metal device, its queue and the pipeline are used from any thread, and the decode tables
// under a lock.
final class MetalPictureConverter: @unchecked Sendable {
    // MARK: - Property
    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let pipeline: any MTLComputePipelineState
    private let yCbCrPipeline: any MTLComputePipelineState
    private let decodeTables = OSAllocatedUnfairLock<[TransferFunction: any MTLBuffer]>(uncheckedState: [:])
    // The table bound where the steps decode by none.
    private let emptyTable: any MTLBuffer
    private let surfaces: SurfacePool<any MTLTexture>

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
        guard
            let library = try? device.makeLibrary(source: WorkingKernelSource.text, options: options),
            let function = library.makeFunction(name: "working"),
            let pipeline = try? device.makeComputePipelineState(function: function),
            let yCbCrFunction = library.makeFunction(name: "workingYCbCr"),
            let yCbCrPipeline = try? device.makeComputePipelineState(function: yCbCrFunction)
        else {
            return nil
        }

        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.yCbCrPipeline = yCbCrPipeline
        self.emptyTable = emptyTable
        self.surfaces = SurfacePool { [device] surface in
            device.makeTexture(
                descriptor: Self.descriptor(
                    width: IOSurfaceGetWidth(surface),
                    height: IOSurfaceGetHeight(surface),
                    usage: .shaderWrite
                ),
                iosurface: surface,
                plane: 0
            )
        }
    }

    // MARK: - Public
    // The working values of `buffer`, a buffer of `format`'s pixel format and of `storedSize` pixels, displayed at
    // `displaySize` by `transform`, top left origin, by `steps`. Nil where the steps are `formulas`, the buffer is of
    // another size or format, the transform is no whole-pixel turn or flip, or Metal does not run the conversion.
    func picture(
        from buffer: CVPixelBuffer,
        format: DecodedFormat,
        storedSize: CGSize,
        displaySize: Size,
        transform: CGAffineTransform,
        steps: ConversionSteps
    ) -> PictureSurface? {
        let width = Int(displaySize.width)
        let height = Int(displaySize.height)
        guard
            CVPixelBufferGetPixelFormatType(buffer) == format.pixelFormat,
            CVPixelBufferGetWidth(buffer) == Int(storedSize.width),
            CVPixelBufferGetHeight(buffer) == Int(storedSize.height),
            Self.isWholePixelMap(transform),
            let (placement, matrix, table) = arguments(of: steps, transform: transform),
            let stored = textures(of: buffer, format: format),
            let (_, output, picture) = surfaces.surface(width: width, height: height)
        else {
            return nil
        }

        guard
            let commands = queue.makeCommandBuffer(),
            let encoder = commands.makeComputeCommandEncoder()
        else {
            return nil
        }
        for (index, texture) in stored.enumerated() {
            encoder.setTexture(texture, index: index)
        }
        encoder.setTexture(output, index: stored.count)
        placement.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 0) }
        matrix.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 1) }
        encoder.setBuffer(table, offset: 0, index: 2)
        switch format {
        case let .yCbCr(layout):
            encoder.setComputePipelineState(yCbCrPipeline)
            Self.arguments(of: layout).withUnsafeBytes {
                encoder.setBytes($0.baseAddress!, length: $0.count, index: 3)
            }

        case .halfFloatRGBA:
            encoder.setComputePipelineState(pipeline)
        }
        let group = MTLSize(width: 16, height: 16, depth: 1)
        encoder.dispatchThreadgroups(
            MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1),
            threadsPerThreadgroup: group
        )
        encoder.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()
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

    // The kernel's `YCbCr`: the range's offsets and scales, the siting and subsampling, the matrix's constants and the
    // shift, in single precision.
    private static func arguments(of layout: YCbCrLayout) -> [Float] {
        [
            Float(layout.lumaOffset), Float(layout.lumaScale), Float(layout.chromaOffset), Float(layout.chromaScale),
            Float(layout.chromaSiting.x), Float(layout.chromaSiting.y),
            Float(layout.sampling.horizontal), Float(layout.sampling.vertical),
            Float(layout.lumaRed), Float(layout.lumaBlue), Float(layout.lumaGreen),
            Float(bitPattern: UInt32(layout.shift))
        ]
    }

    // The textures of the buffer's planes the kernel reads, made on its surface: the half floats, or the luma and the
    // chroma code values. Nil for a buffer with no surface.
    private func textures(
        of buffer: CVPixelBuffer,
        format: DecodedFormat
    ) -> [any MTLTexture]? {
        let planes: [(MTLPixelFormat, Int)] = switch format {
        case let .yCbCr(layout):
            layout.bitDepth > 8 ? [(.r16Uint, 0), (.rg16Uint, 1)] : [(.r8Uint, 0), (.rg8Uint, 1)]

        case .halfFloatRGBA:
            [(.rgba16Float, 0)]
        }
        guard let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue() else { return nil }

        let isPlanar = CVPixelBufferIsPlanar(buffer)
        let textures = planes.compactMap { pixelFormat, plane -> (any MTLTexture)? in
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: pixelFormat,
                width: isPlanar ? CVPixelBufferGetWidthOfPlane(buffer, plane) : CVPixelBufferGetWidth(buffer),
                height: isPlanar ? CVPixelBufferGetHeightOfPlane(buffer, plane) : CVPixelBufferGetHeight(buffer),
                mipmapped: false
            )
            descriptor.usage = .shaderRead
            descriptor.storageMode = .shared

            return device.makeTexture(descriptor: descriptor, iosurface: surface, plane: plane)
        }

        return textures.count == planes.count ? textures : nil
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
