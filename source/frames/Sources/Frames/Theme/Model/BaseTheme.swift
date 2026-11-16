//
//  BaseTheme.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The floor every theme merges over. Its values are part of the contract, so they are kept exactly as written.
enum BaseTheme {
    static let text = """
        {
          "baseWidth": 1206,
          "font": ["Apple SD Gothic Neo"],
          "colors": {
            "accent": "#ED2929", "onAccent": "#FFFFFF",
            "background": "#FFFFFF", "text": "#000000", "border": "#D9D9D9",
            "emphasis": "#FFD43B", "shadow": "#00000059"
          },
          "styles": {
            "subtitle":   { "size": 58, "weight": "bold", "color": "#FFFFFF", "emphasis": "emphasis",
                            "background": { "color": "#000000B8", "padding": [12, 24], "radius": 16 },
                            "placement": "bottom", "offset": 160, "align": "center" },
            "headline":   { "size": 72, "weight": "bold", "color": "#FFFFFF", "emphasis": "emphasis",
                            "stroke": { "width": 6, "color": "#000000" },
                            "placement": "top", "offset": 220, "align": "center" },
            "label":      { "size": 36, "weight": "bold", "color": "onAccent",
                            "background": { "color": "accent", "padding": [8, 16], "radius": 12 }, "lines": 1 },
            "banner":     { "size": 38, "weight": "regular", "color": "text", "lineHeight": 64 },
            "bannerHead": { "size": 44, "weight": "bold", "color": "text", "lineHeight": 64 },
            "heading":    { "size": 44, "weight": "bold", "color": "accent", "lineHeight": 80 }
          },
          "shapes": {
            "box":       { "width": 8, "radius": 18, "color": "accent" },
            "fill":      { "color": "#FFD43B80" },
            "dim":       { "color": "#0000008C" },
            "arrow":     { "width": 10, "length": 160, "head": 32, "color": "accent" },
            "border":    { "width": 3 },
            "shadow":    { "radius": 24, "offset": [0, 8], "color": "shadow" },
            "label":     { "sides": ["right", "bottom", "left", "top"] }
          },
          "area":      { "padding": 14, "cropPadding": 40 },
          "placement": { "padding": 40 },
          "image":     { "bannerPadding": 40 },
          "layout":    { "gap": 40, "padding": 40 },
          "defaults":  { "transition": "cut", "filter": "none",
                         "animation": { "title": { "label": "pop" }, "shape": "none", "media": "none", "adjust": "none" } }
        }
        """
    // The text above is fixed and well formed, so reading it cannot fail.
    static let value: JSONValue = try! JSONReader().read(text)
}
