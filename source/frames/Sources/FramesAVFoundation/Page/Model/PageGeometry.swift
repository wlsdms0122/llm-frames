//
//  PageGeometry.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Frames

// The boxes of a page of a PDF and how its user space maps to its media pixels, by the table of FRAMES-3 PDF pages:
// `cropBox` is the page's crop box intersected with its media box, its corners in order, `rotation` its `Rotate` taken
// modulo 360, and `userUnit` the points in one unit of user space. Core Graphics intersects none of the boxes, returns
// `Rotate` as written and ignores `UserUnit`, so each is taken here.
struct PageGeometry: Equatable {
    // MARK: - Property
    let cropBox: CGRect
    let rotation: Int
    let userUnit: Double

    // The page's size in media pixels: the crop box times `userUnit`, its sides swapped at 90 and 270.
    var size: Size {
        let width = userUnit * cropBox.width
        let height = userUnit * cropBox.height

        return rotation % 180 == 0 ? Size(width: width, height: height) : Size(width: height, height: width)
    }

    // User space to media pixels, whose (0, 0) is the top left of the crop box turned clockwise by `rotation`, y down.
    var toMediaPixels: CGAffineTransform {
        let u = userUnit
        let (x0, y0, x1, y1) = (cropBox.minX, cropBox.minY, cropBox.maxX, cropBox.maxY)

        switch rotation {
        case 90:
            return CGAffineTransform(a: 0, b: u, c: u, d: 0, tx: -u * y0, ty: -u * x0)

        case 180:
            return CGAffineTransform(a: -u, b: 0, c: 0, d: u, tx: u * x1, ty: -u * y0)

        case 270:
            return CGAffineTransform(a: 0, b: -u, c: -u, d: 0, tx: u * y1, ty: u * x1)

        default:
            return CGAffineTransform(a: u, b: 0, c: 0, d: -u, tx: -u * x0, ty: u * y1)
        }
    }

    // MARK: - Initializer
    // A `rotation` that is not a multiple of 90, and a page whose width or height in media pixels is under 1, have no
    // geometry, and throw why.
    init(
        mediaBox: CGRect,
        cropBox: CGRect,
        rotation: Int,
        userUnit: Double
    ) throws(PageFault) {
        let angle = (rotation % 360 + 360) % 360
        guard angle % 90 == 0 else { throw .rotation(rotation) }

        self.cropBox = cropBox.standardized.intersection(mediaBox.standardized)
        self.rotation = angle
        self.userUnit = userUnit

        let size = self.cropBox.isNull ? Size(width: 0, height: 0) : self.size
        guard size.width >= 1, size.height >= 1 else { throw .size(size) }
    }

    // The geometry of `page` as its dictionary writes it, `UserUnit` 1 where it writes none.
    init(page: CGPDFPage) throws(PageFault) {
        var userUnit: CGPDFReal = 1
        if let dictionary = page.dictionary, !CGPDFDictionaryGetNumber(dictionary, "UserUnit", &userUnit) {
            userUnit = 1
        }

        try self.init(
            mediaBox: page.getBoxRect(.mediaBox),
            cropBox: page.getBoxRect(.cropBox),
            rotation: Int(page.rotationAngle),
            userUnit: Double(userUnit)
        )
    }

    // MARK: - Public
    // User space to the device space of a bitmap of `region` at `scale`, whose origin is its bottom left: a media pixel
    // (X, Y) lies at (s X - x, height - (s Y - y)).
    func transform(
        for region: PageRegion,
        scale: Double
    ) -> CGAffineTransform {
        let toDevice = CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: -scale,
            tx: -Double(region.x),
            ty: Double(region.height + region.y)
        )

        return toMediaPixels.concatenating(toDevice)
    }

    // MARK: - Private
}
