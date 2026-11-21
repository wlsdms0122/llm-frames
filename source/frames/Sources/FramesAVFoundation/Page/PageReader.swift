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
// into an extended sRGB context of floats, where DeviceRGB and DeviceGray are taken as `srgb` and every tagged space
// is converted by Core Graphics. A page's checks are made once: what it draws, by `PageContentWalker`, and each colour
// space it draws in, by `PageColorRamp`. Core Graphics draws one document from several threads at once.
final class PageReader: @unchecked Sendable {
    // MARK: - Property
    let path: String
    let pageCount: Int

    private let document: CGPDFDocument
    private let checks = OSAllocatedUnfairLock<[Int: PageCheck]>(initialState: [:])
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

    // Refuses a page that draws content another file holds or content the View event shows otherwise than Core
    // Graphics draws it, and where `reading` is not a `platform` one, a page that sets drawn text in a font its file
    // does not embed or draws in a colour space this decoder does not convert by the fixed formulas. A reading that
    // names a colour space other than `srgb` reads the page's untagged colour in it, which this decoder does only on a
    // page that draws in no other colour space.
    func check(
        _ number: Int,
        reading: PictureReading?
    ) throws {
        let result = try pageCheck(number)
        if let fault = result.drawing {
            throw DecoderError.unreadablePage(file: path, page: number, fault: fault)
        }
        if case .platform = reading { return }

        if let fault = result.font ?? result.color {
            throw DecoderError.unreadablePage(file: path, page: number, fault: fault)
        }
        if let colorSpace = reading?.colorSpace, colorSpace != .srgb, !result.drawsOnlyUntaggedColor {
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
    private func pageCheck(_ number: Int) throws -> PageCheck {
        if let result = checks.withLock({ $0[number] }) { return result }
        let (page, _) = try self.page(number)

        let content = PageContentWalker(document: document).content(of: page)
        let spaces = content.colorSpaces.map { ($0, PageColorSpace($0)) }
        var colorFault = content.faults.first { if case .colorSpace = $0 { true } else { false } }
        for (written, space) in spaces where colorFault == nil {
            colorFault = try PageColorRamp.fault(of: space, written: written)
        }
        let result = PageCheck(
            drawing: content.faults.first { fault in
                switch fault {
                case .externalContent, .viewEvent:
                    true

                default:
                    false
                }
            },
            font: content.faults.first { if case .unembeddedFont = $0 { true } else { false } },
            color: colorFault,
            drawsOnlyUntaggedColor: spaces.allSatisfy { _, space in
                if case .pattern(base: nil) = space { return true }

                return space.isUntagged
            }
        )
        checks.withLock { $0[number] = result }

        return result
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
