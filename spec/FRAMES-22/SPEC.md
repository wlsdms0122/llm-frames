# FRAMES-22: Theme

Status: accepted

## Summary

The theme: the base theme every theme merges over, styles, defaults, how themes merge and in what precedence, and a form's theme.

## Motivation

Look must change without touching documents. Sizes, colours, styles and default presets live in one merged object whose base values are fixed, so a template that leaves a key unset gets the same value everywhere.

## Rules

`theme` prints the base theme, and that output is also the list of every key a theme can hold. Its values are part of this contract, like the presets of [FRAMES-16](../FRAMES-16/SPEC.md), so a template that leaves a key unset gets the same value on every frames of the same major version. `colors`, `styles` and `defaults.animation.title` (keyed by style name) are open maps: any name may be added. A name that is referred to must exist: a style, a colour, or a `title` key that names no style stops. So does a preset named by `defaults` that is not there, whether or not a clip takes that default, and the stop names the default's place in the theme. A theme file and a document's `theme` hold only the keys they change, and an unknown key stops. `--theme` and a document's `theme` take `<pack>/<name>` or an absolute path, and a document's `theme` also takes a theme object.

Merging goes key by key through the theme's own structure: the top-level groups, each colour, each style and its properties, each shape and its properties, each entry of `defaults`, each entry of `defaults.animation`, and each style in its `title` map. Below that every value replaces the one under it whole: a `background`, a `stroke`, a transition choice like `{preset, seconds}`, a list.

Precedence, from weakest:

```
base theme < --theme file < document theme < keys on the clip or op
```

A document inside another starts from the theme in effect where it is written: a compound clip from its document's, and a document given as a template argument from the caller's, not the template's. A template starts from the base theme ([FRAMES-17](../FRAMES-17/SPEC.md)).

### Base theme

The base theme is the floor every theme merges over, not the look of a form. Its open maps carry common text roles (`subtitle`, `headline`, `bannerHead`), as a browser's default style sheet carries headings, and a form's pack changes what it needs.

```json
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
```

### Styles

A style is a named set of text properties. Any name is allowed, and frames reads three names itself, the default style of each text part it draws: `label` (shape labels), `banner` (banner lines) and `heading` (layout headings).

| Property | Meaning |
| --- | --- |
| `size` | font size. Every style has one |
| `weight` | `regular` or `bold`. The default is `regular` |
| `color`, `emphasis` | text colour, and the colour of `**text**`. The defaults are the `text` and `emphasis` colours |
| `lineHeight` | distance between baselines. The default is 1.25 × size |
| `stroke` | `{width, color}`: an outline with round joins, where strokes never show overlapping. `width` is required, since a stroke is written to be seen. Without `color` it takes the `text` colour. Absent means none |
| `background` | `{color, padding, radius}`: a box behind the text, or `false`. `padding` is `[vertical, horizontal]`, in the order CSS writes two values. Without `color` it takes the `background` colour, and without `padding` or `radius` they are 0. Absent means none |
| `placement`, `offset` | default placement ([FRAMES-1](../FRAMES-1/SPEC.md)) |
| `align` | `left`, `center` or `right`. The default is `left` |
| `lines` | `1` keeps the text on one line. Absent means no limit |

A style without `size` stops when the theme is merged, wherever it is written, since no text can be set in it. A stronger theme that changes a style may leave out its size when a weaker one gives it. A style a document names that the theme in effect there does not hold stops, naming where it is named and listing the styles that theme holds.

### Defaults

`defaults` holds the presets a form uses when a clip names none. They are part of a form's look, which is why they live in the theme: shorts pop their subtitles, evidence does not. `animation` holds `title` (keyed by style name, which covers labels through the `label` style), `shape`, `media` and `adjust`. Anything not listed is `none`, the transition default is `cut`, and the filter default is `none`. A clip whose media is a compound clip or a template instance takes no default filter, since the clips inside it already took theirs.

### A form's theme

A form's theme lives in its pack ([FRAMES-25](../FRAMES-25/SPEC.md)) and holds only the keys it changes. The `shorts` pack's theme, `shorts/shorts`:

```json
{ "baseWidth": 1080,
  "colors": { "accent": "#FF3B30", "emphasis": "#FFE14D" },
  "styles": {
    "subtitle": { "size": 66, "background": false, "stroke": { "width": 7, "color": "#000000" }, "offset": 330 },
    "headline": { "size": 84, "offset": 110 },
    "label":    { "size": 40 } },
  "shapes": { "box": { "width": 10 } },
  "defaults": { "transition": { "preset": "push-up", "seconds": 0.3 },
                "animation": { "title": { "subtitle": "pop", "headline": "none", "label": "pop" }, "shape": "draw", "media": "pop" } } }
```

## Interactions

Themes come from packs ([FRAMES-17](../FRAMES-17/SPEC.md)). Its values are versioned as [FRAMES-18](../FRAMES-18/SPEC.md) says. A template's theme is [FRAMES-17](../FRAMES-17/SPEC.md).

## Alternatives considered

A base theme that is a form's look: it is the floor, as a browser's default style sheet is.

## Notes
