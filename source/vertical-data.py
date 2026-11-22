#!/usr/bin/env python3
# Writes the vertical orientations UAX #50 gives each scalar, from the Unicode Character Database.
#
#   python3 source/vertical-data.py 17.0.0
#
# The version is the Unicode version of the Swift standard library frames builds with, as for `source/bidi-data.py`.
import os
import re
import sys
import urllib.request

TEXT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "frames", "Sources", "Frames", "Text"))
WIDTH = 120

ORIENTATIONS = {
    "U": "upright",
    "R": "rotated",
    "Tu": "transformedUpright",
    "Tr": "transformedRotated",
}


def fetch(version, name):
    with urllib.request.urlopen(f"https://www.unicode.org/Public/{version}/ucd/{name}") as response:
        return response.read().decode("utf-8")


def entries(text):
    for line in text.splitlines():
        missing = re.match(r"#\s*@missing:\s*(.*)", line)
        body = missing.group(1) if missing else line.split("#", 1)[0]
        fields = [field.strip() for field in body.split(";")]
        if len(fields) < 2 or not fields[0]:
            continue
        first, _, last = fields[0].partition("..")
        yield int(first, 16), int(last or first, 16), fields[1], bool(missing)


def orientations(text):
    table = [None] * 0x110000
    for missing in (True, False):
        for first, last, value, is_missing in entries(text):
            if is_missing == missing:
                table[first:last + 1] = [value] * (last - first + 1)
    runs = []
    for scalar, value in enumerate(table):
        if not runs or runs[-1][1] != value:
            runs.append((scalar, value))
    return runs


def wrapped(items, indent):
    lines, line = [], indent
    for item in items:
        if len(line) + len(item) + 1 > WIDTH and line.strip():
            lines.append(line.rstrip())
            line = indent
        line += item + " "
    lines.append(line.rstrip())
    return "\n".join(lines).rstrip(",")


def header(name, created):
    return f"//\n//  {name}\n//  Frames\n//\n//  Created by JSilver on {created}.\n//\n\n"


def orientation_file(runs, version):
    cases = "\n".join(f"    case {ORIENTATIONS[value]}" for value in ORIENTATIONS)
    starts = wrapped([f"0x{scalar:04X}," for scalar, _ in runs], "        ")
    values = wrapped([f".{ORIENTATIONS[value]}," for _, value in runs], "        ")
    return header("VerticalOrientation.swift", "11/23/26") + f"""\
// The orientation of a character in vertical text by UAX #50, its Vertical_Orientation values named in full, as `init`
// tells them from a scalar. Swift gives no Vertical_Orientation, so the table is the Unicode {version} data of
// VerticalOrientation.txt, which `source/vertical-data.py` writes, unassigned scalars taking the defaults it gives
// their blocks.
enum VerticalOrientation: Equatable, Sendable {{
{cases}

    // MARK: - Property
    // The first scalar of each stretch of scalars that share an orientation, in order, and the orientation of each
    // stretch.
    private static let starts: [UInt32] = [
{starts}
    ]
    private static let orientations: [VerticalOrientation] = [
{values}
    ]

    // Whether a character of this orientation stands upright in a vertical line, as CSS `text-orientation: mixed` sets
    // it: every orientation but `rotated`, which is set turned 90 degrees clockwise.
    var isUpright: Bool {{
        self != .rotated
    }}

    // MARK: - Initializer
    init(_ scalar: Unicode.Scalar) {{
        var low = 0
        var high = Self.starts.count
        while high - low > 1 {{
            let middle = (low + high) / 2
            if Self.starts[middle] <= scalar.value {{
                low = middle
            }} else {{
                high = middle
            }}
        }}

        self = Self.orientations[low]
    }}

    // MARK: - Public
    // MARK: - Private
}}
"""


def main():
    version = sys.argv[1]
    runs = orientations(fetch(version, "VerticalOrientation.txt"))
    with open(os.path.join(TEXT, "Model", "VerticalOrientation.swift"), "w") as file:
        file.write(orientation_file(runs, version))


main()
