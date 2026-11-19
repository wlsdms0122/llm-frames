# FRAMES-22: Theme

Status: accepted

## Summary

The theme: the base theme every theme merges over, text styles, shape styles, the border and shadow of media clips, defaults, how themes merge and in what precedence, and a pack's theme.

## Motivation

A look must change without touching the edit. An editor swaps a series' typeface or accent colour, or gives every subtitle a box instead of an outline, across every episode at once, as the text styles of Final Cut Pro and the Essential Graphics styles of Premiere Pro do. So sizes, colours, text and shape styles and default presets live in one merged object, apart from the documents that use them. Its base values are fixed, so a template that leaves a key unset gets the same value everywhere, and the base is a plain floor that any look builds on without first undoing another look.

## Rules

`theme` prints the base theme, and that output is also the list of every group a theme can hold. The keys of a text style and of a shape style are the tables below. Its values are part of this contract, like the presets of [FRAMES-16](../FRAMES-16/SPEC.md), so a template that leaves a key unset gets the same value on every frames of the same major version. `colors`, `styles`, `shapes` and `defaults.animation.title` (keyed by text style name) are open maps: any name may be added. A name that is referred to must exist: a colour, a text style, a shape style, or a `title` key that names no text style stops. So does a preset named by `defaults` that is not there, whether or not a clip takes that default, and the stop names the default's place in the theme. So does a theme colour such a preset names with the default's arguments applied (a cover or a bloom `color`) that the merged theme, its own colours and those it is merged over, does not hold. A theme file and a document's `theme` hold only the keys they change, and an unknown key stops. `--theme` and a document's `theme` take `<pack>/<name>` or an absolute path, and a document's `theme` also takes a theme object.

Merging goes key by key through the theme's own structure: the top-level groups, each key of `placement`, `border` and `shadow`, each colour, each text style and its properties, each shape style and its properties, each entry of `defaults`, each entry of `defaults.animation`, and each style in its `title` map. Below that every value replaces the one under it whole: a `background`, a `stroke`, a shape style's `shadow` object, a preset choice like `{preset, seconds}`, a list such as `font`.

Precedence, from weakest:

```
base theme < --theme file < document theme < keys on the clip
```

A document inside another starts from the theme in effect where it is written: a compound clip from its document's, and a document given as a template argument from the caller's, not the template's. A template starts from the base theme ([FRAMES-17](../FRAMES-17/SPEC.md)).

frames reads no style by name. A title names its style and its runs' styles ([FRAMES-5](../FRAMES-5/SPEC.md)), and a shape names its shape style ([FRAMES-11](../FRAMES-11/SPEC.md)). The time labels of `still` and `sheet` are drawn in a fixed style of the tool, not from the theme ([FRAMES-23](../FRAMES-23/SPEC.md)).

### Base theme

The base theme is the floor every theme merges over, not the look of a kind of result. It holds two text styles nearly every edit uses, `title` and `subtitle`, as a browser's default style sheet carries headings, white text on black, a title safe margin, a border and a shadow for media clips, no shape styles, and no default motion or filter. A pack's theme changes what its look needs. Lengths are written at `baseWidth` 1920, so on a frame 1920 pixels wide they are output pixels.

```json
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
  "border": { "width": 4, "color": "accent" },
  "shadow": { "radius": 32, "offset": [0, 12], "color": "shadow" },
  "defaults": { "transition": "cut", "filter": "none",
                "animation": { "title": {}, "shape": "none", "media": "none", "adjust": "none" } }
}
```

| Group | Meaning |
| --- | --- |
| `baseWidth` | the frame width at which theme lengths are written. The length scale is the frame width over it ([FRAMES-1](../FRAMES-1/SPEC.md)) |
| `font` | font families in the order they are tried ([FRAMES-5](../FRAMES-5/SPEC.md)) |
| `colors` | named colours, which any colour value may name ([FRAMES-1](../FRAMES-1/SPEC.md)). `text` is the default text colour and `background` the default format background ([FRAMES-9](../FRAMES-9/SPEC.md)) |
| `styles` | text styles ([Styles](#styles)) |
| `shapes` | shape styles ([Shape styles](#shape-styles)) |
| `placement.padding` | the title safe margin: the distance of every placement name from the edges of the frame ([FRAMES-1](../FRAMES-1/SPEC.md)). 96 is 5% of 1920 |
| `border` | `{width, color}`: the border a media clip draws with `border: true`. A clip's `border` colour replaces `color` ([FRAMES-11](../FRAMES-11/SPEC.md)) |
| `shadow` | `{radius, offset, color}`: the drop shadow a clip draws with `shadow: true`. `radius` is the standard deviation of its blur and `offset` is `[x, y]`, both theme lengths ([FRAMES-20](../FRAMES-20/SPEC.md)) |
| `defaults` | the presets a clip takes when it names none ([Defaults](#defaults)) |

### Styles

A text style is a named set of text properties. Any name is allowed. A run's style gives that run its character properties, and the clip's style gives the paragraph properties ([FRAMES-5](../FRAMES-5/SPEC.md)).

| Property | Kind | Meaning |
| --- | --- | --- |
| `size` | character | font size. Every style has one |
| `weight` | character | `regular` or `bold`. The default is `regular` |
| `color` | character | text colour. The default is the `text` colour |
| `stroke` | character | `{width, color}`: an outline with round joins, where strokes never show overlapping, or `false`. `width` is required, since a stroke is written to be seen. Without `color` it takes the `text` colour. Absent means none |
| `lineHeight` | paragraph | distance between baselines. The default is 1.25 × size |
| `background` | paragraph | `{color, padding, radius}`: a box behind the text, or `false`. `padding` is `[vertical, horizontal]`, in the order CSS writes two values. Without `color` it takes the `background` colour, and without `padding` or `radius` they are 0. Absent means none |
| `placement`, `offset` | paragraph | default placement, and the distance from the top or bottom edge that replaces `placement.padding` there ([FRAMES-1](../FRAMES-1/SPEC.md)) |
| `align` | paragraph | `left`, `center` or `right`: where each line sits in the title's text box, which is its `width` or its widest line ([FRAMES-5](../FRAMES-5/SPEC.md)). The default is `left` |
| `lines` | paragraph | the most lines the text may take, a whole number of 1 or more. `1` keeps it on one line, and text that needs more lines than `lines` stops ([FRAMES-5](../FRAMES-5/SPEC.md)). Absent means no limit |

A style without `size` stops when the theme is merged, wherever it is written, since no text can be set in it. A stronger theme that changes a style may leave out its size when a weaker one gives it. A style a document names that the theme in effect there does not hold stops, naming where it is named and listing the styles that theme holds.

### Shape styles

A shape style is a named set of defaults for a shape clip, as a text style is for a title. Any name is allowed, and a shape clip names one in its `style`. Keys written on the clip win over its style's ([FRAMES-11](../FRAMES-11/SPEC.md)).

| Property | Form |
| --- | --- |
| `fill` | a colour, a gradient ([FRAMES-11](../FRAMES-11/SPEC.md)), or `false` for none |
| `stroke` | `{color, width, join, cap, start, end, dash, dashOffset}`, its `color` a colour or a gradient, or `false` for none |
| `radius` | a theme length: the corner radius of a `rect` |
| `outset` | a theme length: how far the outline a `rect` or `ellipse` draws grows on every side, its box staying as written |
| `shadow` | `true` for the theme `shadow`, `false` for none, or `{radius, offset, color}`, whose missing keys come from the theme `shadow` |

What each property draws, and its defaults, are [FRAMES-11](../FRAMES-11/SPEC.md). A shape style with another key stops. A shape whose style and keys give it neither a fill nor a stroke stops ([FRAMES-11](../FRAMES-11/SPEC.md)).

### Defaults

`defaults` holds the presets a clip takes when it names none. They are part of a look, which is why they live in the theme: a look sets its own default motion, so one pack's theme dissolves between shots and fades its subtitles in, while the base theme cuts and moves nothing. Each value is a preset choice ([FRAMES-14](../FRAMES-14/SPEC.md), [FRAMES-15](../FRAMES-15/SPEC.md)), arguments included.

| Entry | Taken by | Base |
| --- | --- | --- |
| `transition` | every storyline clip after the first ([FRAMES-8](../FRAMES-8/SPEC.md)) | `"cut"` |
| `filter` | storyline clips other than solids, and media clips with a picture | `"none"` |
| `animation.title` | a title, by the name of its clip `style` | `{}` |
| `animation.shape` | shape clips | `"none"` |
| `animation.media` | media clips with a picture | `"none"` |
| `animation.adjust` | adjustment clips | `"none"` |

A title whose style is not in `animation.title` takes `"none"`. A clip whose media is a compound clip or a template instance takes no default filter, since the clips inside it already took theirs.

### A pack's theme

A pack's theme lives in its `themes/` ([FRAMES-17](../FRAMES-17/SPEC.md)) and holds only the keys it changes. A broadcast look, `studio/broadcast`, with a lower third's styles, a boxed subtitle, two shape styles and gentle default motion:

```json
{ "font": ["Avenir Next", "Apple SD Gothic Neo"],
  "colors": { "accent": "#F2B705", "ink": "#101418" },
  "styles": {
    "subtitle": { "size": 44, "stroke": false, "background": { "color": "#000000B3", "padding": [6, 16], "radius": 6 } },
    "name":     { "size": 56, "weight": "bold", "placement": "bottom-left", "offset": 160 },
    "role":     { "size": 36, "color": "accent" } },
  "shapes": {
    "bar":     { "fill": "accent", "radius": 4 },
    "outline": { "stroke": { "width": 6, "color": "accent" }, "radius": 12, "outset": 8 } },
  "border": { "width": 6, "color": "ink" },
  "defaults": { "transition": { "preset": "frames/fade", "seconds": 0.5 }, "filter": "frames/warm",
                "animation": { "title": { "subtitle": "frames/fade", "name": "frames/slide-left" }, "media": "frames/fade" } } }
```

## Interactions

Themes come from packs ([FRAMES-17](../FRAMES-17/SPEC.md)). Its values are versioned as [FRAMES-18](../FRAMES-18/SPEC.md) says. A template's theme is [FRAMES-17](../FRAMES-17/SPEC.md). Theme lengths and the length scale are [FRAMES-1](../FRAMES-1/SPEC.md). Runs and line limits are laid out by [FRAMES-5](../FRAMES-5/SPEC.md). Shape, border and shadow keys on clips are [FRAMES-11](../FRAMES-11/SPEC.md). The resolved document writes the theme out as values ([FRAMES-19](../FRAMES-19/SPEC.md)).

## Alternatives considered

A base theme that is the look of a kind of result: it is the floor, as a browser's default style sheet is, and a result with another look would first undo it. Styles that frames reads by name for text it adds itself beside a clip: a name the engine reads is a purpose built into it, and a document names the style each clip uses. A fixed group for each kind of mark (an outline, a highlight, a darkened surround, a pointer): each is a purpose, while an open map of shape styles gives any look a name, as text styles do. Groups for laying out stills (gaps between pictures, a margin around a canvas): a still is a sequence like any other, laid out with clips, transforms and content fit ([FRAMES-6](../FRAMES-6/SPEC.md)).

## Notes
