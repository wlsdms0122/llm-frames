#!/usr/bin/env python3
# Writes the cursive scripts of every scalar that tracking reads, from the Unicode Character Database.
#
#   python3 source/cursive-data.py 17.0.0
#
# The version is the Unicode version of the Swift standard library frames builds with, so the scripts agree with the
# general category it reads from Swift. A script is cursive when ArabicShaping.txt gives one of its characters the
# Joining_Type D (Dual_Joining), so the set follows the Unicode data without a list of scripts: it holds the cursive
# scripts CSS Text 3 names in its Appendix D and those Unicode encoded after it.
import os
import sys
import urllib.request

TEXT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "frames", "Sources", "Frames", "Text"))
WIDTH = 120


def fetch(version, name):
    with urllib.request.urlopen(f"https://www.unicode.org/Public/{version}/ucd/{name}") as response:
        return response.read().decode("utf-8")


def entries(text):
    for line in text.splitlines():
        fields = [field.strip() for field in line.split("#", 1)[0].split(";")]
        if len(fields) < 2 or not fields[0]:
            continue
        first, _, last = fields[0].partition("..")
        yield int(first, 16), int(last or first, 16), fields[1:]


def codes(aliases):
    table = {}
    for line in aliases.splitlines():
        fields = [field.strip() for field in line.split("#", 1)[0].split(";")]
        if len(fields) >= 3 and fields[0] == "sc":
            table[fields[2]] = fields[1]
            table[fields[1]] = fields[1]
    return table


def scripts(text, codes_):
    table = {}
    for first, last, fields in entries(text):
        for scalar in range(first, last + 1):
            table[scalar] = {codes_[name] for name in fields[0].split()}
    return table


def cursive(shaping_text, script):
    return {
        code for first, last, fields in entries(shaping_text) if fields[1] == "D"
        for scalar in range(first, last + 1) for code in script.get(scalar, set())
    }


def runs(script, extensions, cursive_):
    runs_ = []
    for scalar in range(0x110000):
        value = tuple(sorted((script.get(scalar, set()) | extensions.get(scalar, set())) & cursive_))
        if not runs_ or runs_[-1][1] != value:
            runs_.append((scalar, value))
    return runs_


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


def script_file(runs_, cursive_, version):
    starts = wrapped([f"0x{scalar:04X}," for scalar, _ in runs_], "        ")
    values = wrapped(["[" + ", ".join(f'"{code}"' for code in value) + "]," for _, value in runs_], "        ")
    return header("CursiveScript.swift", "11/22/26") + f"""\
// The cursive scripts a scalar belongs to by its Script and Script_Extensions values, as their ISO 15924 codes in
// order, as CSS Text 3 reads a character's script with its Script_Extensions. A script is cursive when one of its
// characters is dual-joining (Joining_Type D) in ArabicShaping.txt, so the cursive scripts are
// {", ".join(sorted(cursive_))}.
// Swift gives no Script property, so the table is the Unicode {version} data of Scripts.txt, ScriptExtensions.txt
// and ArabicShaping.txt, which `source/cursive-data.py` writes.
enum CursiveScript {{
    // MARK: - Property
    // The first scalar of each stretch of scalars that share their cursive scripts, in order, and the cursive scripts
    // of each stretch.
    private static let starts: [UInt32] = [
{starts}
    ]
    private static let scripts: [[String]] = [
{values}
    ]

    // MARK: - Initializer
    // MARK: - Public
    static func codes(of scalar: Unicode.Scalar) -> [String] {{
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

        return Self.scripts[low]
    }}

    // MARK: - Private
}}
"""


def main():
    version = sys.argv[1]
    codes_ = codes(fetch(version, "PropertyValueAliases.txt"))
    script = scripts(fetch(version, "Scripts.txt"), codes_)
    extensions = scripts(fetch(version, "ScriptExtensions.txt"), codes_)
    cursive_ = cursive(fetch(version, "ArabicShaping.txt"), script)
    with open(os.path.join(TEXT, "Model", "CursiveScript.swift"), "w") as file:
        file.write(script_file(runs(script, extensions, cursive_), cursive_, version))


main()
