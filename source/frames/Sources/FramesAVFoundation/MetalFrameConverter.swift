//
//  MetalFrameConverter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

import CoreVideo
import Foundation
import Frames
import IOSurface
import Metal

// Takes a frame given as a surface to an SDR output's code values on the GPU, by `OutputKernelSource`, straight into
// the pixel buffer an encoder writes (FRAMES-21 Pictures): `kCVPixelFormatType_32BGRA` at eight bits and
// `kCVPixelFormatType_64RGBALE` at sixteen, the pixel formats `FrameConverter` writes an SDR output in. It reads the
// surface where it lies and writes the buffer's surface where it lies, and runs each conversion whole before it
// returns. The buffer's colour tags are the caller's.
final class MetalFrameConverter {
    // MARK: - Property
    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let pipeline: any MTLComputePipelineState
    private let outputFormat: MTLPixelFormat
    // The kernel's `Output`: three columns of four floats, then the steps, the transfer and whether alpha is kept.
    private let arguments: [UInt32]

    // MARK: - Initializer
    // Nil on a machine with no Metal device, for an output whose steps are `formulas` or whose transfer is neither the
    // sRGB transfer nor BT.1886's, and for another pixel format.
    init?(
        output: ColorConversion,
        keepsAlpha: Bool,
        pixelFormat: OSType
    ) {
        let functionName: String
        let outputFormat: MTLPixelFormat
        switch pixelFormat {
        case kCVPixelFormatType_32BGRA:
            (functionName, outputFormat) = ("eight", .r32Uint)

        case kCVPixelFormatType_64RGBALE:
            (functionName, outputFormat) = ("sixteen", .rgba16Uint)

        default:
            return nil
        }
        guard let (matrix, steps, transfer) = Self.steps(of: output.outputSteps) else { return nil }

        let options = MTLCompileOptions()
        if #available(macOS 15.0, *) {
            options.mathMode = .safe
        } else {
            options.fastMathEnabled = false
        }
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let library = try? device.makeLibrary(source: OutputKernelSource.text, options: options),
            let function = library.makeFunction(name: functionName),
            let pipeline = try? device.makeComputePipelineState(function: function)
        else {
            return nil
        }

        let columns: [Float] = (0..<3).flatMap { column in (0..<3).map { Float(matrix.rows[$0][column]) } + [0] }
        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.outputFormat = outputFormat
        self.arguments = columns.map(\.bitPattern) + [steps, transfer, keepsAlpha ? 1 : 0, 0]
    }

    // MARK: - Public
    // Gives whether the frame went in, which it does not where the buffer is of another size, has no surface, or Metal
    // does not run the conversion.
    func copy(
        _ frame: PictureSurface,
        into buffer: CVPixelBuffer
    ) -> Bool {
        let width = frame.width
        let height = frame.height
        guard
            CVPixelBufferGetWidth(buffer) == width,
            CVPixelBufferGetHeight(buffer) == height,
            let target = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue(),
            let input = device.makeTexture(
                descriptor: Self.descriptor(.rgba16Float, width: width, height: height, usage: .shaderRead),
                iosurface: frame.surface,
                plane: 0
            ),
            let output = device.makeTexture(
                descriptor: Self.descriptor(outputFormat, width: width, height: height, usage: .shaderWrite),
                iosurface: target,
                plane: 0
            ),
            let commands = queue.makeCommandBuffer(),
            let encoder = commands.makeComputeCommandEncoder()
        else {
            return false
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        arguments.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 0) }
        encoder.dispatchThreadgroups(
            MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1)
        )
        encoder.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()

        return commands.status == .completed
    }

    // MARK: - Private
    // The matrix, steps and transfer the kernel takes for the steps, nil for steps it does not run.
    private static func steps(of steps: OutputSteps) -> (matrix: ColorMatrix, steps: UInt32, transfer: UInt32)? {
        switch steps {
        case .clip:
            return (.identity, 0, 0)

        case let .decodeMatrixClipEncode(fromLinearSRGB, .sRGB):
            return (fromLinearSRGB, 1, 0)

        case let .decodeMatrixClipEncode(fromLinearSRGB, .bt1886):
            return (fromLinearSRGB, 1, 1)

        case .decodeMatrixClipEncode, .formulas:
            return nil
        }
    }

    private static func descriptor(
        _ pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        usage: MTLTextureUsage
    ) -> MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage
        descriptor.storageMode = .shared

        return descriptor
    }
}
