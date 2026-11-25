//
//  BaseTheme.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The floor every theme merges over. Its values are part of the contract, so they are kept exactly as written.
package enum BaseTheme {
    package static let text = """
        {
          "baseWidth": 1920,
          "font": ["Helvetica Neue", "Apple SD Gothic Neo"],
          "colors": { "text": "#FFFFFF", "background": "#000000", "accent": "#FFFFFF", "shadow": "#00000080" },
          "styles": {
            "title":    { "size": 96, "weight": "bold", "placement": "center", "align": "center" },
            "subtitle": { "size": 48, "weight": "regular", "stroke": { "width": 3, "color": "#000000" },
                          "placement": "bottom", "offset": 108, "align": "center", "lines": 2 }
          },
          "shapes": {},
          "placement": { "padding": 96 },
          "border":    { "width": 4, "color": "accent", "align": "inside" },
          "shadow":    { "radius": 32, "offset": [0, 12], "color": "shadow" },
          "defaults":  { "transition": "cut", "filter": "none",
                         "animation": { "title": {}, "shape": "none", "media": "none", "adjustment": "none" } }
        }
        """
    // The text above is fixed and well formed, so reading it cannot fail.
    static let value: JSONValue = try! JSONReader().read(text)
}
