#!/usr/bin/env python3
# Writes the bidirectional classes and paired brackets UAX #9 reads, from the Unicode Character Database, and a sample
# of its conformance tests for the tests of frames to run.
#
#   python3 source/bidi-data.py 17.0.0
#
# The version is the Unicode version of the Swift standard library frames builds with, so the classes agree with the
# scalar properties it reads from Swift, such as general category and mirroring. The conformance files are some
# megabytes each, so the sample, which is all the tests run, is every case of BidiCharacterTest.txt before its
# permutations and every hundredth after, and every two hundredth case of BidiTest.txt.
import os
import re
import sys
import urllib.request

TEXT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "frames", "Sources", "Frames", "Text"))
RESOURCES = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "frames", "Tests", "FramesTests", "Text", "Resources")
)
WIDTH = 120
CHARACTER_STEP = 100
CLASS_STEP = 200

CLASSES = {
    "L": "leftToRight",
    "R": "rightToLeft",
    "AL": "arabicLetter",
    "EN": "europeanNumber",
    "ES": "europeanSeparator",
    "ET": "europeanTerminator",
    "AN": "arabicNumber",
    "CS": "commonSeparator",
    "NSM": "nonspacingMark",
    "BN": "boundaryNeutral",
    "B": "paragraphSeparator",
    "S": "segmentSeparator",
    "WS": "whiteSpace",
    "ON": "otherNeutral",
    "LRE": "leftToRightEmbedding",
    "LRO": "leftToRightOverride",
    "RLE": "rightToLeftEmbedding",
    "RLO": "rightToLeftOverride",
    "PDF": "popDirectionalFormat",
    "LRI": "leftToRightIsolate",
    "RLI": "rightToLeftIsolate",
    "FSI": "firstStrongIsolate",
    "PDI": "popDirectionalIsolate",
}
LONG = {
    "Left_To_Right": "L", "Right_To_Left": "R", "Arabic_Letter": "AL", "European_Terminator": "ET",
    "Boundary_Neutral": "BN",
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
        yield int(first, 16), int(last or first, 16), fields[1:], bool(missing)


def classes(text):
    table = [None] * 0x110000
    for missing in (True, False):
        for first, last, fields, is_missing in entries(text):
            if is_missing == missing:
                value = LONG.get(fields[0], fields[0])
                table[first:last + 1] = [value] * (last - first + 1)
    runs = []
    for scalar, value in enumerate(table):
        if not runs or runs[-1][1] != value:
            runs.append((scalar, value))
    return runs


def decompositions(text):
    table = {}
    for line in text.splitlines():
        fields = line.split(";")
        if fields[5] and not fields[5].startswith("<") and " " not in fields[5]:
            table[int(fields[0], 16)] = int(fields[5], 16)
    return table


def brackets(text, singletons):
    table = []
    for first, _, fields, is_missing in entries(text):
        if is_missing or fields[1] == "n":
            continue
        opening = first if fields[1] == "o" else int(fields[0], 16)
        table.append((first, "opening" if fields[1] == "o" else "closing", singletons.get(opening, opening)))
    return table


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


def class_file(runs, version):
    cases = "\n".join(f"    case {CLASSES[value]}" for value in CLASSES)
    starts = wrapped([f"0x{scalar:04X}," for scalar, _ in runs], "        ")
    values = wrapped([f".{CLASSES[value]}," for _, value in runs], "        ")
    return header("BidiClass.swift", "11/22/26") + f"""\
// The bidirectional character types of UAX #9, its Bidi_Class values named in full, as `init` tells them from a
// scalar. Swift gives no Bidi_Class, so the table is the Unicode {version} data of DerivedBidiClass.txt, which
// `source/bidi-data.py` writes, unassigned scalars taking the defaults it gives their blocks.
enum BidiClass: Equatable, Sendable {{
{cases}

    // MARK: - Property
    // The first scalar of each stretch of scalars that share a class, in order, and the class of each stretch.
    private static let starts: [UInt32] = [
{starts}
    ]
    private static let classes: [BidiClass] = [
{values}
    ]

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

        self = Self.classes[low]
    }}

    // MARK: - Public
    // MARK: - Private
}}
"""


def bracket_file(table, version):
    entries_ = wrapped(
        [f"0x{scalar:04X}: PairedBracket(type: .{kind}, opening: 0x{opening:04X})," for scalar, kind, opening in table],
        "        ",
    )
    return header("PairedBracket.swift", "11/22/26") + f"""\
// A paired bracket of UAX #9, its Bidi_Paired_Bracket_Type and the opening bracket of its pair, which rule N0 matches
// brackets by. The opening bracket is canonically decomposed, so a bracket pairs with the canonical equivalent of its
// pair. The table is the Unicode {version} data of BidiBrackets.txt, which `source/bidi-data.py` writes.
struct PairedBracket: Equatable, Sendable {{
    enum BracketType: Equatable, Sendable {{
        case opening
        case closing
    }}

    // MARK: - Property
    let type: BracketType
    let opening: UInt32

    private static let brackets: [UInt32: PairedBracket] = [
{entries_}
    ]

    // MARK: - Initializer
    private init(type: BracketType, opening: UInt32) {{
        self.type = type
        self.opening = opening
    }}

    init?(_ scalar: Unicode.Scalar) {{
        guard let bracket = Self.brackets[scalar.value] else {{ return nil }}

        self = bracket
    }}

    // MARK: - Public
    // MARK: - Private
}}
"""


def leading_comments(lines):
    comments = []
    for line in lines:
        if not line.startswith("#"):
            break
        comments.append(line)
    return comments


def character_cases(text):
    lines = text.splitlines()
    kept, is_permutation, count = leading_comments(lines), False, 0
    for line in lines[len(kept):]:
        if line.startswith("# Permutations"):
            is_permutation = True
        if line.startswith("#") or not line.strip():
            continue
        if not is_permutation or count % CHARACTER_STEP == 0:
            kept.append(line)
        count += is_permutation
    return "\n".join(kept) + "\n"


def class_cases(text):
    lines = text.splitlines()
    kept, count = leading_comments(lines), 0
    headers = {}
    for line in lines[len(kept):]:
        if line.startswith("@"):
            headers[line.split(":", 1)[0]] = line
            continue
        if line.startswith("#") or not line.strip():
            continue
        if count % CLASS_STEP == 0:
            kept.extend(headers.values())
            headers = {}
            kept.append(line)
        count += 1
    return "\n".join(kept) + "\n"


def main():
    version = sys.argv[1]
    runs = classes(fetch(version, "extracted/DerivedBidiClass.txt"))
    table = brackets(fetch(version, "BidiBrackets.txt"), decompositions(fetch(version, "UnicodeData.txt")))
    with open(os.path.join(TEXT, "Model", "BidiClass.swift"), "w") as file:
        file.write(class_file(runs, version))
    with open(os.path.join(TEXT, "Model", "PairedBracket.swift"), "w") as file:
        file.write(bracket_file(table, version))
    os.makedirs(RESOURCES, exist_ok=True)
    with open(os.path.join(RESOURCES, "BidiCharacterTest.txt"), "w") as file:
        file.write(character_cases(fetch(version, "BidiCharacterTest.txt")))
    with open(os.path.join(RESOURCES, "BidiTest.txt"), "w") as file:
        file.write(class_cases(fetch(version, "BidiTest.txt")))


main()
