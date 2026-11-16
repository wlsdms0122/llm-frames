//
//  ImageOperationContent.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What an image operation does. A colour is as written, a theme colour name or `#RRGGBB(AA)`, and nil takes the
// theme's: `background` for a pad, the shape's own colour for a shape. `border` is `border` for `true`.
enum ImageOperationContent: Equatable, Sendable {
    case crop(AreaForm)
    case resize(ResizeForm)
    case pad(Inset, color: String?)
    case shape(ShapeKind, area: AreaForm, label: String?, side: Side?, color: String?)
    case adjust(JSONValue, area: AreaForm?)
    case title(String, position: PositionForm, anchor: String, style: String, width: Double?)
    case banner([BannerLine], edge: Side)
    case border(color: String)
}
