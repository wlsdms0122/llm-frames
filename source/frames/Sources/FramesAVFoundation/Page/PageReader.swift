//
//  PageReader.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import Frames
import os

// A PDF opened with Core Graphics, whose pages the decoder checks and draws (FRAMES-3 PDF pages). A page is drawn on its
// pixel grid at a scale, a region of it in one draw, clipped to its crop box, with Core Graphics' parser and renderer,
// into an extended sRGB context of floats, where DeviceRGB and DeviceGray are taken as `srgb` and Core Graphics
// converts every tagged space. What a page draws is read once, by `PageContentWalker`. Core Graphics draws one
// document from several threads at once.
final class PageReader: @unchecked Sendable {
    // MARK: - Property
    let path: String
    let pageCount: Int

    private let document: CGPDFDocument
    private let contents = OSAllocatedUnfairLock<[Int: PageContent]>(initialState: [:])
    private let extendedSRGB = CGColorSpace(name: CGColorSpace.extendedSRGB)

    // MARK: - Initializer
    // Nil where the file is no PDF. A PDF that opens only with a password throws; one encrypted with an empty user
    // password opens.
    init?(path: String) throws {
        guard let document = CGPDFDocument(URL(fileURLWithPath: path) as CFURL) else { return nil }
        if !document.isUnlocked, !document.unlockWithPassword("") {
            throw DecoderError.lockedDocument(file: path)
        }

        self.path = path
        self.pageCount = document.numberOfPages
        self.document = document
    }

    // MARK: - Public
    // The page numbered `number`, from 1, with its geometry.
    func page(_ number: Int) throws -> (CGPDFPage, PageGeometry) {
        guard (1...max(1, pageCount)).contains(number), let page = document.page(at: number) else {
            throw DecoderError.noPage(file: path, page: number, count: pageCount)
        }

        do {
            return (page, try PageGeometry(page: page))
        } catch {
            throw DecoderError.unreadablePage(file: path, page: number, fault: error)
        }
    }

    func probed(_ number: Int) throws -> ProbedPage {
        let (_, geometry) = try page(number)
        try check(number, reading: nil)

        return ProbedPage(size: geometry.size, pageCount: pageCount)
    }

    // Where `reading` is not a `platform` one, refuses a page that sets drawn text in a font its file does not embed.
    // A reading that names a colour space other than `srgb` reads the page's untagged colour in it, which this decoder
    // does only on a page that draws in no other colour space.
    func check(
        _ number: Int,
        reading: PictureReading?
    ) throws {
        if case .platform = reading { return }
        let content = try content(of: number)

        if let font = content.unembeddedFont {
            throw DecoderError.unreadablePage(file: path, page: number, fault: .unembeddedFont(font))
        }
        if let colorSpace = reading?.colorSpace, colorSpace != .srgb, !content.drawsOnlyUntaggedColor {
            throw DecoderError.unreadablePage(file: path, page: number, fault: .untaggedColor(colorSpace))
        }
    }

    // `region` of page `number`'s grid at `scale`, read as `reading` says, after the page's checks. An analysis picture
    // is the page over white.
    func picture(
        _ number: Int,
        region: PageRegion,
        scale: Double,
        reading: PictureReading
    ) throws -> Bitmap {
        let (page, geometry) = try self.page(number)
        try check(number, reading: reading)

        let space: CGColorSpace?
        let intent: CGColorRenderingIntent
        let conversion: (@Sendable (RGB) -> RGB)?
        switch reading {
        case let .working(colorSpace, _), let .analysis(colorSpace):
            space = extendedSRGB
            intent = .defaultIntent
            conversion = colorSpace.flatMap { colorSpace in
                guard colorSpace != .srgb else { return nil }
                let untagged = MediaColorConversion(.space(colorSpace))

                return { untagged.working($0, toneMapping: nil) }
            }

        case let .platform(colorSpace):
            space = CGColorSpaceCreateExtended(colorSpace.imageSpace)
            intent = .relativeColorimetric
            let managed = ColorConversion(space: colorSpace)
            conversion = { managed.working($0) }
        }
        guard let space else { throw DecoderError.unreadable(file: path) }
        // A page read for its values is the page over white, the paper a viewer shows (FRAMES-3 PDF pages).
        let isAnalysis = if case .analysis = reading { true } else { false }

        var pixels = try PageRasterizer.pixels(
            of: page,
            width: region.width,
            height: region.height,
            transform: geometry.transform(for: region, scale: scale),
            clip: geometry.cropBox,
            space: space,
            intent: intent,
            isOverWhite: isAnalysis
        )

        if isAnalysis {
            pixels.convertColors(width: region.width) { (conversion?($0) ?? $0).clipped(to: 0...1) }

            return Self.bitmap(eightBit: pixels, width: region.width, height: region.height)
        }
        if let conversion { pixels.convertColors(width: region.width, by: conversion) }

        return Self.bitmap(halfFloat: pixels, width: region.width, height: region.height)
    }

    // MARK: - Private
    private func content(of number: Int) throws -> PageContent {
        if let content = contents.withLock({ $0[number] }) { return content }
        let (page, _) = try self.page(number)

        let content = PageContentWalker().content(of: page)
        contents.withLock { $0[number] = content }

        return content
    }

    private static func bitmap(
        halfFloat pixels: [Float],
        width: Int,
        height: Int
    ) -> Bitmap {
        let halves = pixels.map(Float16.init)

        return Bitmap(
            width: width,
            height: height,
            depth: .halfFloat,
            bytesPerRow: width * 8,
            pixels: halves.withUnsafeBytes { Data($0) }
        )
    }

    private static func bitmap(
        eightBit pixels: [Float],
        width: Int,
        height: Int
    ) -> Bitmap {
        // A component that is no number is written 0, as the clamp passes it on unchanged.
        let bytes = pixels.map { UInt8(($0.isNaN ? 0 : min(max($0, 0), 1) * 255).rounded()) }

        return Bitmap(width: width, height: height, depth: .eight, bytesPerRow: width * 4, pixels: Data(bytes))
    }
}
