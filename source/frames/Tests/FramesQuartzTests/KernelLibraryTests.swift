//
//  KernelLibraryTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
@testable import FramesQuartz
import Testing

@Suite("KernelLibrary Tests")
struct KernelLibraryTests {
    // MARK: - Property
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "the blend and filter sources compile into one library that hands out their kernels by name",
        arguments: ["blendNormalPlaceholder", "filterIdentityPlaceholder"]
    )
    func handsOutKernel(name: String) throws {
        // Given
        let sut = try KernelLibrary.shared.get()

        // When
        let kernel = try sut.colorKernel(named: name)

        // Then
        #expect(kernel.name == name)
    }

    @Test("the normal placeholder composites premultiplied source-over on sRGB-encoded values")
    func compositesOnEncodedValues() throws {
        // Given
        let sut = try KernelLibrary.shared.get()
        let extent = CGRect(x: 0, y: 0, width: 2, height: 2)
        let source = CIImage(color: CIColor(red: 0.5, green: 0, blue: 0, alpha: 0.5, colorSpace: colorSpace)!)
        let backdrop = CIImage(color: CIColor(red: 0, green: 0.5, blue: 1, alpha: 1, colorSpace: colorSpace)!)
        let context = CIContext(options: [.workingColorSpace: colorSpace, .workingFormat: CIFormat.RGBAf])

        // When
        let kernel = try sut.colorKernel(named: "blendNormalPlaceholder")
        let image = try #require(kernel.apply(extent: extent, arguments: [source, backdrop]))
        var pixel = [Float](repeating: 0, count: 4)
        context.render(
            image,
            toBitmap: &pixel,
            rowBytes: 16,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBAf,
            colorSpace: colorSpace
        )

        // Then
        // Core Image premultiplies the half transparent red to (0.25, 0, 0, 0.5), and source-over adds the backdrop
        // times one minus its alpha, with no conversion from the sRGB-encoded values.
        let expected: [Float] = [0.25, 0.25, 0.5, 1]
        for (value, want) in zip(pixel, expected) {
            #expect(abs(value - want) < 1e-5)
        }
    }
}
