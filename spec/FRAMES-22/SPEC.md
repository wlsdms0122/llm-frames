# FRAMES-22: Theme

Status: accepted

## Summary

The theme: the base theme every theme merges over, text styles, shape styles, the border and shadow of media clips, defaults, how themes merge and in what precedence, and a pack's theme.

## Motivation

A look must change without touching the edit. An editor swaps a series' typeface or accent colour, or gives every subtitle a box instead of an outline, across every episode at once, as the text styles of Final Cut Pro and the Essential Graphics styles of Premiere Pro do. So sizes, colours, text and shape styles and default presets live in one merged object, apart from the documents that use them. Its base values are fixed, so a template that leaves a key unset gets the same value everywhere, and the base is a plain floor that any look builds on without first undoing another look.

## Rules

`theme` prints the base theme, and that output is also the list of every group a theme can hold. The keys of a text style and of a shape style are the tables below. Its values are part of this contract, like the presets of [FRAMES-16](../FRAMES-16/SPEC.md), so a template that leaves a key unset gets the same value on every frames of the same major version. `colors`, `styles`, `shapes` and `defaults.animation.title` (keyed by text style name) are open maps: any name may be added. A name that is referred to must exist: a colour, a text style, a shape style, or a `title` key that names no text style stops. So does a preset named by `defaults` that is not there, whether or not a clip takes that default, and the stop names the default's place in the theme. So does a theme colour such a preset names with the default's arguments applied (a cover or a bloom `color`) that the merged theme, its own colours and those it is merged over, does not hold. A theme file and a document's `theme` hold only the keys they change, and an unknown key stops. `--theme` and a document's `theme` take `<pack>/<name>` or an absolute path, and a document's `theme` also takes a theme object.

**Every layer of a look merges over the one below it leaf by leaf**: a stronger theme over a weaker one, a clip's choice over the theme's default choice ([Defaults](#defaults)), a clip's own layer over its style ([FRAMES-11](../FRAMES-11/SPEC.md)), and a title's `character` and `paragraph` over its runs' styles and its clip style's paragraph attributes ([FRAMES-11](../FRAMES-11/SPEC.md)). A clip's own layer is its static value together with the structure its keyframes give, and keyframes are no layer: they time the leaves of the merged value ([FRAMES-4](../FRAMES-4/SPEC.md)). The layer below gives defaults, and whatever writes over it changes only what it writes.

- An object takes the upper layer's keys over the lower one's, key by key and inside nested objects: the top-level groups, each colour, each text style and shape style and each of their properties, a `stroke`, a `shadow`, a `background`, a `highlight`, an `underline`, a style's `features`, each entry of `defaults` and of `defaults.animation`, and each style in its `title` map. So a stronger theme that writes `{"stroke": {"color": "red"}}` for a shape style keeps the weaker theme's stroke `width`.
- Every other value replaces the one under it: a number, a colour, a name, a list such as `font`, a `dash` or a gradient's `stops`.
- **A shorthand expands to the leaves it names, over the value below, and nothing more**, statically and in a keyframe alike, before it merges and before its structure is compared ([FRAMES-4](../FRAMES-4/SPEC.md)). `true` names every leaf of its value as the value below, each leaf `null`, so it turns a `shadow`, a `border` or an `underline` on with the look's leaves: over a style's shadow object it is that shadow, and over `false` or no value its leaves are the value's defaults (the theme `shadow`, the theme `border`, the face's underline in the run's colour). A media clip's `border` colour names only `color`, as `{"color": "#F00"}`, over the theme's border.
- A value of another form replaces the one under it whole: a colour over a gradient, a linear gradient over a radial one, a preset name over a preset choice object, and a choice of one preset over a choice of another, whose arguments are another preset's parameters. Over `false`, or where the layer below has no value, the upper value stands alone.
- A stroke's `color` and `gradient` are one paint leaf: writing either replaces the other.
- `false` turns the value below off.
- A leaf a key requires is required of the merged value, so a stroke whose layers together give no `width` stops. **A clip's partial value over a layer that gives none (`false`, or no value) stands alone, and a leaf it requires that is still missing stops, naming the clip and the theme layer that gave none**, since a value that cannot do what it says stops (README): a stroke recoloured where the look has no stroke has no stroke to recolour, and a width frames chose for it would draw a line the look does not hold. So a rect that writes `stroke: {"color": "red"}` over a shape style whose stroke a `--theme` file turns `false` stops under that theme, naming the clip and the file.

Precedence, from weakest:

```
base theme < --theme file < document theme < keys on the clip
```

The keys on the clip are a shape's appearance keys over its shape style, a media clip's `border` and `shadow` over the theme's, a title's `character` over its runs' styles and its `paragraph` over its clip style's paragraph attributes, and a clip's `transition`, `animation` and `filter` over the theme's `defaults`.

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
  "border": { "width": 4, "color": "accent", "align": "inside" },
  "shadow": { "radius": 32, "offset": [0, 12], "color": "shadow" },
  "defaults": { "transition": "cut", "filter": "none",
                "animation": { "title": {}, "shape": "none", "media": "none", "adjust": "none" } }
}
```

| Group | Meaning |
| --- | --- |
| `baseWidth` | the frame width at which theme lengths are written. The length scale is the frame width over it ([FRAMES-1](../FRAMES-1/SPEC.md)) |
| `font` | font families in the order they are tried, for every text style that has no `font` of its own ([FRAMES-5](../FRAMES-5/SPEC.md)) |
| `colors` | named colours, each a hex colour or a `color()` value as [FRAMES-26](../FRAMES-26/SPEC.md) gives them, which any colour value may name ([FRAMES-1](../FRAMES-1/SPEC.md)). `text` is the default text colour and `background` the default format background ([FRAMES-9](../FRAMES-9/SPEC.md)) |
| `styles` | text styles ([Styles](#styles)) |
| `shapes` | shape styles ([Shape styles](#shape-styles)) |
| `placement.padding` | the title safe margin: the distance of every placement name from the edges of the frame ([FRAMES-1](../FRAMES-1/SPEC.md)). 96 is 5% of 1920 |
| `border` | `{width, color, align}`: the border a media clip draws with `border: true`, its `align` `inside`, `center` or `outside`, the side of the box's edge it lies on ([FRAMES-11](../FRAMES-11/SPEC.md)). A clip's `border` colour replaces `color`, and its object the keys it writes |
| `shadow` | `{radius, offset, color}`: the drop shadow a clip draws with `shadow: true`. `radius` is the standard deviation of its blur and `offset` is `[x, y]`, both theme lengths ([FRAMES-20](../FRAMES-20/SPEC.md)) |
| `defaults` | the presets a clip takes when it names none ([Defaults](#defaults)) |

### Styles

A text style is a named set of text properties. Any name is allowed. A run's style gives that run its character properties, and the clip's style gives the paragraph properties ([FRAMES-5](../FRAMES-5/SPEC.md)). A title's `character` merges over every run's style, and its `paragraph` over the paragraph attributes of its clip style ([FRAMES-11](../FRAMES-11/SPEC.md)).

| Property | Kind | Meaning |
| --- | --- | --- |
| `font` | character | font families in the order they are tried ([FRAMES-5](../FRAMES-5/SPEC.md)). The default is the theme `font` |
| `size` | character | font size. Every style has one |
| `weight` | character | a whole number from 100 to 900, as CSS `font-weight`, or its name: `thin` 100, `extralight` 200, `light` 300, `regular` 400, `medium` 500, `semibold` 600, `bold` 700, `extrabold` 800, `black` 900, the names of the OpenType weight classes. The default is `regular` |
| `italic` | character | `true` for the family's italic face, `false` for its upright one ([FRAMES-5](../FRAMES-5/SPEC.md)). The default is `false` |
| `tracking` | character | space added after each character, in thousandths of an em, as After Effects' Tracking and CSS `letter-spacing` ([FRAMES-5](../FRAMES-5/SPEC.md)). Negative tightens. The default is 0 |
| `kerning` | character | `metrics`, the font's own kerning, or `none`, as CSS `font-kerning`. The default is `metrics` |
| `features` | character | OpenType feature settings, each a feature tag (four printable ASCII characters, as OpenType writes tags, and any other key stops) to a whole number 0 or more, as CSS `font-feature-settings`: `{"tnum": 1, "liga": 0}`. 0 turns a feature off, 1 on, and a larger number picks an alternate. `kern` is set by `kerning` and stops here. The default is `{}`, the features the font's script turns on |
| `baselineShift` | character | a theme length the run's glyphs are raised by, up positive, toward the line-over side, which is the right in a vertical line ([FRAMES-5](../FRAMES-5/SPEC.md#writing-mode)), as After Effects' Baseline Shift. The default is 0 |
| `color` | character | text colour. The default is the `text` colour |
| `stroke` | character | `{width, color}`: an outline with round joins, where strokes never show overlapping, or `false`. `width` is required, since a stroke is written to be seen. Without `color` it takes the `text` colour. Absent means none |
| `highlight` | character | `{color, padding, radius}`, or `false`: a box behind the run's glyphs on each line it occupies, as a highlighter marks text on a page and CSS draws the background of an inline box ([FRAMES-5](../FRAMES-5/SPEC.md)). `padding` is `[vertical, horizontal]`, in the order CSS writes two values, above and below the line and at its ends, which in a vertical line are its right and left and its top and bottom ([FRAMES-5](../FRAMES-5/SPEC.md#writing-mode)), and it takes no part in layout. Without `color` it takes the `background` colour, and without `padding` or `radius` they are 0. Absent means none |
| `underline` | character | `true`, `{width, offset, color}` or `false`: a line under the run's glyphs ([FRAMES-5](../FRAMES-5/SPEC.md)). `width` is its thickness and `offset` the distance from the baseline down to its top edge, both theme lengths, as CSS `text-decoration-thickness` and `text-underline-offset`. `true` turns it on with the leaves below it ([Rules](#rules)), and a key that no layer gives takes the face's own underline thickness and position and the run's colour. Absent means none |
| `textOrientation` | character | `mixed`, `upright` or `sideways`: how the run's characters stand in a vertical line, each by Unicode's Vertical_Orientation, every one upright, read left to right, or every one on its side, as CSS `text-orientation` names them and as After Effects chooses with its Standard Vertical Roman Alignment ([FRAMES-5](../FRAMES-5/SPEC.md#writing-mode)). It changes nothing in a horizontal line. The default is `mixed` |
| `textCombineUpright` | character | `none` or `all`: `all` sets the run's text on each of its lines side by side in one upright square 1 em long of a vertical line, narrowed to fit it, a horizontal-in-vertical composition, as CSS `text-combine-upright` names it and After Effects' Tate-Chu-Yoko sets it ([FRAMES-5](../FRAMES-5/SPEC.md#horizontal-in-vertical-composition)). It changes nothing in a horizontal line. The default is `none` |
| `lineHeight` | paragraph | distance between baselines. The default is 1.25 × size |
| `background` | paragraph | `{color, padding, radius}`: a box behind the text box, which grows the title's box by its padding ([FRAMES-5](../FRAMES-5/SPEC.md)), or `false`. `padding` is `[vertical, horizontal]`, in the order CSS writes two values, along the block axis and the inline axis, as CSS `padding-block` and `padding-inline`, so in a vertical writing mode the first pads the right and left of the text box and the second its top and bottom ([FRAMES-5](../FRAMES-5/SPEC.md#writing-mode)). Without `color` it takes the `background` colour, and without `padding` or `radius` they are 0. Absent means none |
| `placement`, `offset` | paragraph | default placement, and the distance from the top or bottom edge that replaces `placement.padding` there ([FRAMES-1](../FRAMES-1/SPEC.md)) |
| `direction` | paragraph | `auto`, `ltr` or `rtl`: the paragraph direction the Unicode Bidirectional Algorithm lays the title's text out in, as CSS `direction` and HTML `dir` name it, `auto` taking it from the text's first strong character ([FRAMES-5](../FRAMES-5/SPEC.md#direction)). The default is `auto` |
| `writingMode` | paragraph | `horizontal-tb`, `vertical-rl` or `vertical-lr`: whether the title's lines are horizontal and stacked from top to bottom, or vertical and stacked from right to left, as Chinese, Japanese and Korean are set, or from left to right, as Mongolian is, as CSS `writing-mode` names them ([FRAMES-5](../FRAMES-5/SPEC.md#writing-mode)). The default is `horizontal-tb` |
| `align` | paragraph | `left`, `center` or `right`: where each line sits in the title's text box, which is its `width` or its widest line, whatever direction the line reads in ([FRAMES-5](../FRAMES-5/SPEC.md)), `left` and `right` being the top and the bottom in a vertical line, as CSS reads `text-align` there ([FRAMES-5](../FRAMES-5/SPEC.md#writing-mode)). The default is the side the paragraph direction starts from, `left` for `ltr` and `right` for `rtl`, as CSS `text-align: start` |
| `lines` | paragraph | the most lines the text may take, a whole number of 1 or more. `1` keeps it on one line, and text that needs more lines than `lines` stops ([FRAMES-5](../FRAMES-5/SPEC.md)). Absent means no limit |

`baseWidth` and a style's `size` and `lineHeight` are above 0, and `placement.padding` and a style's `offset` are 0 or more. A value outside its range stops where it is written, as a `weight`, a feature or a `lines` outside what its row gives does.

A style without `size` stops when the theme is merged, wherever it is written, since no text can be set in it. A stronger theme that changes a style may leave out its size when a weaker one gives it. A style a document names that the theme in effect there does not hold stops, naming where it is named and listing the styles that theme holds.

### Shape styles

A shape style is a named set of defaults for a shape clip, as a text style is for a title. Any name is allowed, and a shape clip names one in its `style`. A key written on the clip, its static value with the structure its keyframes give, merges over its style's value leaf by leaf, and `false` turns it off ([FRAMES-11](../FRAMES-11/SPEC.md)); its keyframes time the leaves of the merged value ([FRAMES-4](../FRAMES-4/SPEC.md)). Themes merge over each other by the same rule ([above](#rules)).

| Property | Form |
| --- | --- |
| `fill` | a colour, a gradient ([FRAMES-11](../FRAMES-11/SPEC.md)), or `false` for none |
| `stroke` | `{color, gradient, width, align, join, cap, start, end, dash, dashOffset}`, its `color` a colour and its `gradient` a gradient, at most one of the two, and its `start` and `end` each an arrowhead's name or `{shape, scale}`, or `false` for none |
| `radius` | a theme length: the corner radius of a `rect` |
| `outset` | a theme length: how far the outline a `rect` or `ellipse` draws grows on every side, its box staying as written |
| `shadow` | `true` for on, with a weaker theme's shadow for this style or else the theme `shadow`, `false` for none, or `{radius, offset, color}`, whose missing keys come from the theme `shadow` |

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

**`defaults` is a layer of the look like the others.** A clip's choice written as an object without `preset` merges over the theme's default choice for that clip, key by key, a default written as a preset name read as `{preset: name}`, and the result is checked as a choice ([FRAMES-14](../FRAMES-14/SPEC.md)). So `"animation": {"by": "word"}` on a title plays the default animation of its style by word, `"filter": {"mix": 0.5}` or `{"args": {...}}` on a clip is the default filter at half strength or with those arguments, and `"transition": {"seconds": 1}` is the default transition a second long, and a later change of the default reaches each of them. A filter entry merges over a default filter of one entry, and over a default that is a list it stops, since which entry it changes is ambiguous. Over a default of `"none"` or `"cut"`, or where the clip takes no default (an adjustment clip's `adjust`, an `audioFilter`, a clip whose media is a compound clip), it stops, naming the clip and the theme layer that gave none, as any partial value with nothing below it does ([above](#rules)). A choice that names a preset, a list and `"none"` replace the default whole.

### A pack's theme

A pack's theme lives in its `themes/` ([FRAMES-17](../FRAMES-17/SPEC.md)) and holds only the keys it changes. A broadcast look, `studio/broadcast`, with a lower third's styles, a boxed subtitle with a `keyword` style a run can name to highlight one word, three shape styles, one of them a pointer with an open arrowhead half again as large as the stroke's own, and gentle default motion:

```json
{ "font": ["Avenir Next", "Apple SD Gothic Neo"],
  "colors": { "accent": "#F2B705", "ink": "#101418" },
  "styles": {
    "subtitle": { "size": 44, "stroke": false, "background": { "color": "#000000B3", "padding": [6, 16], "radius": 6 } },
    "name":     { "size": 56, "weight": "bold", "placement": "bottom-left", "offset": 160 },
    "role":     { "size": 36, "color": "accent", "weight": "medium", "tracking": 40 },
    "keyword":  { "size": 44, "color": "ink", "highlight": { "color": "accent", "padding": [2, 8], "radius": 4 } } },
  "shapes": {
    "bar":     { "fill": "accent", "radius": 4 },
    "outline": { "stroke": { "width": 6, "color": "accent" }, "radius": 12, "outset": 8 },
    "pointer": { "stroke": { "width": 6, "color": "accent", "cap": "round", "end": { "shape": "line-arrow", "scale": 1.5 } } } },
  "border": { "width": 6, "color": "ink" },
  "defaults": { "transition": { "preset": "frames/fade", "seconds": 0.5 }, "filter": "frames/warm",
                "animation": { "title": { "subtitle": "frames/fade", "name": "frames/slide-left" }, "media": "frames/fade" } } }
```

## Interactions

Themes come from packs ([FRAMES-17](../FRAMES-17/SPEC.md)). Its values are versioned as [FRAMES-18](../FRAMES-18/SPEC.md) says. A template's theme is [FRAMES-17](../FRAMES-17/SPEC.md). Theme lengths and the length scale are [FRAMES-1](../FRAMES-1/SPEC.md), and colour values [FRAMES-26](../FRAMES-26/SPEC.md). Runs and line limits are laid out by [FRAMES-5](../FRAMES-5/SPEC.md). Shape, border and shadow keys on clips are [FRAMES-11](../FRAMES-11/SPEC.md). The resolved document writes the theme out as values ([FRAMES-19](../FRAMES-19/SPEC.md)).

## Alternatives considered

A base theme that is the look of a kind of result: it is the floor, as a browser's default style sheet is, and a result with another look would first undo it. Styles that frames reads by name for text it adds itself beside a clip: a name the engine reads is a purpose built into it, and a document names the style each clip uses. A fixed group for each kind of mark (an outline, a highlight, a darkened surround, a pointer): each is a purpose, while an open map of shape styles gives any look a name, as text styles do. Groups for laying out stills (gaps between pictures, a margin around a canvas): a still is a sequence like any other, laid out with clips, transforms and content fit ([FRAMES-6](../FRAMES-6/SPEC.md)).

## Notes
