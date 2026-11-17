#!/usr/bin/env python3
# Writes the film looks of packs/film as 33-point 3D LUTs.
#
#   python3 source/film-luts.py
#
# Each look is a fixed chain over sRGB-encoded values, the values a `lut` op maps: a channel mix, a contrast curve, a
# saturation, a split tone, and the black and white points the film fades to. The numbers are the looks, so changing
# one and running this again is how a look is tuned.
import os

import numpy as np

SIZE = 33
LUTS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "packs", "film", "luts"))

LOOKS = {
    "warm-negative": {
        "title": "Warm negative: soft contrast, warm highlights, gentle greens",
        "mix": [[1.03, 0.0, 0.0], [0.05, 0.95, 0.0], [0.0, 0.0, 0.95]],
        "contrast": 3.5,
        "saturation": 0.9,
        "shadows": [-0.01, 0.01, 0.02],
        "highlights": [0.03, 0.01, -0.03],
        "black": 0.03,
        "white": 0.98,
    },
    "tungsten-night": {
        "title": "Tungsten night: cool balance, teal shadows, lights that stay warm",
        "mix": [[0.9, 0.0, 0.0], [0.0, 0.98, 0.0], [0.0, 0.02, 1.04]],
        "contrast": 4.5,
        "saturation": 1.0,
        "shadows": [-0.03, 0.01, 0.03],
        "highlights": [0.03, 0.01, -0.02],
        "black": 0.02,
        "white": 0.96,
    },
    "faded-slide": {
        "title": "Faded slide: rich mid colour, lifted blacks, cyan shadows and warm highlights",
        "mix": [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
        "contrast": 6.0,
        "saturation": 1.15,
        "shadows": [-0.02, 0.01, 0.03],
        "highlights": [0.03, -0.01, 0.01],
        "black": 0.08,
        "white": 0.92,
    },
    "mono-contrast": {
        "title": "Contrasty black and white with deep blacks",
        "mono": [0.35, 0.55, 0.1],
        "contrast": 6.0,
        "black": 0.0,
        "white": 1.0,
    },
    "instant": {
        "title": "Instant film: low contrast, creamy highlights, green-cyan shadows",
        "mix": [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 0.97]],
        "contrast": 3.0,
        "saturation": 0.8,
        "shadows": [-0.02, 0.02, 0.02],
        "highlights": [0.03, 0.02, -0.03],
        "black": 0.1,
        "white": 0.93,
    },
}


def luma(rgb):
    return rgb @ np.array([0.2126, 0.7152, 0.0722])


# An S-curve about 0.5 that keeps 0 at 0 and 1 at 1, steeper in the middle as `steepness` grows.
def contrast(values, steepness):
    def sigmoid(x):
        return 1 / (1 + np.exp(-steepness * (x - 0.5)))

    low, high = sigmoid(0.0), sigmoid(1.0)
    return (sigmoid(values) - low) / (high - low)


def look(rgb, settings):
    if "mono" in settings:
        grey = rgb @ np.array(settings["mono"])
        rgb = np.repeat(grey[..., None], 3, axis=-1)
    else:
        rgb = rgb @ np.array(settings["mix"]).T

    rgb = contrast(np.clip(rgb, 0, 1), settings["contrast"])

    if "saturation" in settings:
        grey = luma(rgb)[..., None]
        rgb = grey + settings["saturation"] * (rgb - grey)
    if "shadows" in settings:
        light = np.clip(luma(rgb), 0, 1)[..., None]
        rgb = rgb + np.array(settings["shadows"]) * (1 - light) ** 2 + np.array(settings["highlights"]) * light ** 2

    rgb = settings["black"] + np.clip(rgb, 0, 1) * (settings["white"] - settings["black"])
    return np.clip(rgb, 0, 1)


def write(name, settings):
    steps = np.linspace(0, 1, SIZE)
    blue, green, red = np.meshgrid(steps, steps, steps, indexing="ij")
    grid = np.stack([red, green, blue], axis=-1).reshape(-1, 3)
    table = look(grid, settings)

    path = os.path.join(LUTS, f"{name}.cube")
    with open(path, "w") as file:
        file.write(f'TITLE "{settings["title"]}"\n')
        file.write(f"LUT_3D_SIZE {SIZE}\n")
        file.write("DOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n")
        for red, green, blue in table:
            file.write(f"{red:.6f} {green:.6f} {blue:.6f}\n")
    print(path)


os.makedirs(LUTS, exist_ok=True)
for name, settings in LOOKS.items():
    write(name, settings)
