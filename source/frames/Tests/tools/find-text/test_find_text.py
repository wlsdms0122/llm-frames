"""Checks the tool frames/find-text of the pack `frames` against frames output recorded in `fixtures/`, so it runs
without frames.

Run from the repository root: python3 -m unittest discover -s source/frames/Tests/tools/find-text

`fixtures/still.json` and `fixtures/video.json` name their media as `/media/board.png`, `/media/clip.mp4` and
`/media/frames`, and each `*.calls.json` holds the frames commands the tool ran on them with what frames printed,
the document it asks about written as `<document>`. `board.png` is a still of six lines of text, `clip.mp4` a 4 second
video at 25 frames a second that shows `Price 4.50` at the top left before 2 seconds and `Price 6.00` at the bottom
right from 2 seconds, and `frames` an image sequence of its frames every half second, read at 2 frames a second.
The documents hold `frames/track-motion` requests beside `frames/find-text` ones, which the tool leaves as written.
"""

import copy
import importlib.machinery
import importlib.util
import json
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.join(HERE, "fixtures")
PROGRAM = os.path.join(HERE, os.pardir, os.pardir, os.pardir, "Sources", "FramesCommand", "Resources", "packs", "frames", "tools", "find-text", "find-text")
# The program is one of frames' resources, which the build copies into its bundle, so no bytecode is written
# beside it.
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("frames_find_text", PROGRAM)
spec = importlib.util.spec_from_loader("frames_find_text", loader)
tool = importlib.util.module_from_spec(spec)
loader.exec_module(tool)


def fixture(name):
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as file:
        return json.load(file)


class Replay(tool.Frames):
    """Frames that answers each command with what the real one printed for it."""

    calls = []
    log = []

    def report(self, arguments):
        arguments = ["<document>" if argument.endswith("/document.json") else argument for argument in arguments]
        Replay.log.append(arguments)
        for call in Replay.calls:
            if call["arguments"] == arguments:
                return call["output"]
        raise AssertionError(f"no recorded output for frames {' '.join(arguments)}")


class Case(unittest.TestCase):
    def setUp(self):
        self.original = tool.Frames
        tool.Frames = Replay
        Replay.log = []

    def tearDown(self):
        tool.Frames = self.original

    def run_document(self, document, calls, *options):
        return self.run_with_report(document, calls, *options)[0]

    def run_with_report(self, document, calls, *options):
        """The filled document and the report of each request filled."""
        Replay.calls = calls
        path = os.path.join(self.directory(), "document.json")
        with open(path, "w", encoding="utf-8") as file:
            json.dump(document, file)
        filled, _, report = tool.run([path, *options], "frames")
        return filled, report

    def directory(self):
        directory = tempfile.mkdtemp(prefix="find-text-test-")
        self.addCleanup(shutil.rmtree, directory, True)
        return directory

    def stop(self, document, calls=None, *options):
        with self.assertRaises(tool.Stop) as raised:
            self.run_document(document, calls or [], *options)
        return str(raised.exception)

    def commands(self, name):
        return [arguments for arguments in Replay.log if arguments[0] == name]


class Recorded(Case):
    def test_still(self):
        # Given a still under shapes, a point and a crop whose requests name its text
        document = fixture("still.json")

        # When the tool writes the rectangles
        result = self.run_document(document, fixture("still.calls.json"))

        # Then each is the rectangle ocr reports, padding included, and the still is read once
        self.assertEqual(result, fixture("still.expected.json"))
        self.assertEqual(len(self.commands("ocr")), 1)

    def test_video(self):
        # Given a video under keyframed areas, a speed, a time remap, a picture in picture, track requests and an image
        # sequence
        document = fixture("video.json")

        # When the tool writes the rectangles
        result = self.run_document(document, fixture("video.calls.json"), "--languages", "en-US")

        # Then each is found on the frame its instant shows, and each frame is read once with the languages
        self.assertEqual(result, fixture("video.expected.json"))
        ocr = self.commands("ocr")
        self.assertEqual(len(ocr), len({tuple(arguments) for arguments in ocr}))
        self.assertTrue(all(arguments[-2:] == ["--languages", "en-US"] for arguments in ocr))

    def test_video_frames(self):
        # Given the video fixture
        result = self.run_document(fixture("video.json"), fixture("video.calls.json"), "--languages", "en-US")

        # When the keyframes of the box on the first clip are read
        keyframes = result["storyline"][0]["connected"][0]["keyframes"]

        # Then the first lies on the line shown before 2 seconds and the second on the line shown after
        self.assertEqual(keyframes[0]["area"], [93.90329, 112, 158.19342, 35])
        self.assertEqual(keyframes[1]["area"], [693.924263, 512, 160.151474, 35])

    def test_not_drawn(self):
        # Given a keyframe of a child of a looped clip past the end of the sequence, and keyframes of a child of a clip
        # at speed 2 and opacity 0, which draws nothing
        document = fixture("video.json")

        # When the tool writes the rectangles
        result = self.run_document(document, fixture("video.calls.json"), "--languages", "en-US")

        # Then each is found on the frame the clip's time map shows there, which timeline --at gives
        self.assertEqual(result["clips"][2]["keyframes"][2]["area"], [699.924263, 518, 148.151474, 23])
        self.assertEqual([keyframe["area"] for keyframe in result["clips"][4]["keyframes"]], [
            [99.90329, 118, 146.19342, 23], [699.924263, 518, 148.151474, 23]
        ])
        self.assertIn(["timeline", "<document>", "--at", "12", "--json"], Replay.log)
        self.assertEqual(self.commands("evaluate") + self.commands("locate") + self.commands("probe"), [])

    def test_image_sequence(self):
        # Given an image sequence's crop and a child's area, both requests for frames/find-text
        result = self.run_document(fixture("video.json"), fixture("video.calls.json"), "--languages", "en-US")

        # When the image sequence is read
        sequence = result["storyline"][3]

        # Then its directory is read once with ocr at the rate its media form writes, at the frame shown at its in
        self.assertEqual(sequence["crop"], [89.90329, 108, 166.19342, 43])
        self.assertEqual(sequence["connected"][0]["area"], [99.90329, 118, 146.19342, 23])
        self.assertEqual([arguments for arguments in self.commands("ocr") if "/media/frames" in arguments], [
            ["ocr", "/media/frames", "--json", "--fps", "2", "--at", "1", "--languages", "en-US"]
        ])

    def test_track_requests_kept(self):
        # Given frames/track-motion requests that name a frames/find-text request's key and an area
        document = fixture("video.json")

        # When the tool writes the rectangles
        result = self.run_document(copy.deepcopy(document), fixture("video.calls.json"), "--languages", "en-US")

        # Then each track request is left as written, and the area it names is the rectangle found on the clip's instant
        shot = result["storyline"][0]
        self.assertEqual(shot["track"], document["storyline"][0]["track"])
        self.assertEqual([clip["track"] for clip in shot["connected"][1:]], [clip["track"] for clip in document["storyline"][0]["connected"][1:]])
        self.assertEqual(shot["connected"][1]["area"], [99.90329, 118, 146.19342, 23])

    def test_report_still(self):
        # Given the still fixture
        document = fixture("still.json")

        # When the tool writes the rectangles with their report
        result, report = self.run_with_report(copy.deepcopy(document), fixture("still.calls.json"))

        # Then each request filled is reported in the order of the document, with its place, its request as written,
        # the still read, the lines it matched and the rectangle written
        self.assertEqual([(entry["place"], entry["key"]) for entry in report], [
            ("storyline[0]#board.connected[0]#sour", "area"),
            ("storyline[0]#board.connected[1]#total", "area"),
            ("storyline[0]#board.connected[2]#range", "area"),
            ("storyline[0]#board.connected[3]#note", "position.area"),
            ("storyline[1]#zoom", "crop")
        ])
        self.assertEqual(report[1], {
            "place": "storyline[0]#board.connected[1]#total", "key": "area",
            "request": {"tool": "frames/find-text", "text": "Total", "nth": 1, "padding": 8},
            "media": "/media/board.png", "mediaTime": None, "page": None,
            "lines": [{"text": "Total saved 1.00", "rect": [77.795659, 483, 238.387482, 23]}],
            "rect": result["storyline"][0]["connected"][1]["area"]
        })
        self.assertEqual([line["text"] for line in report[2]["lines"]], ["Flat white 4.50", "Sourdough 6.00", "Total 10.50"])
        self.assertEqual(report[3]["rect"], result["storyline"][0]["connected"][3]["position"]["area"])

    def test_report_video(self):
        # Given the video fixture
        # When the tool writes the rectangles with their report
        result, report = self.run_with_report(fixture("video.json"), fixture("video.calls.json"), "--languages", "en-US")

        # Then each keyframe's request names the frame read by its media time and the line shown on it
        keyframes = [entry for entry in report if entry["place"] == "storyline[0]#v.connected[0]#k"]
        self.assertEqual([(entry["key"], entry["media"], entry["mediaTime"], entry["page"]) for entry in keyframes], [
            ("keyframes[0].area", "/media/clip.mp4", 0.48, None), ("keyframes[1].area", "/media/clip.mp4", 3, None)
        ])
        self.assertEqual([[line["text"] for line in entry["lines"]] for entry in keyframes], [["Price 4.50"], ["Price 6.00"]])
        self.assertEqual([entry["rect"] for entry in keyframes], [keyframe["area"] for keyframe in result["storyline"][0]["connected"][0]["keyframes"]])

    def test_no_text_forms(self):
        # Given a document whose areas are rectangles
        document = {"kind": "sequence", "storyline": [{"kind": "solid", "color": "#000000", "duration": 1}]}

        # When the tool runs
        result = self.run_document(copy.deepcopy(document), [])

        # Then the document is unchanged and frames is not run
        self.assertEqual(result, document)
        self.assertEqual(Replay.log, [])


class Matching(unittest.TestCase):
    lines = fixture("still.calls.json")
    output = next(call for call in lines if call["arguments"][0] == "ocr")["output"]
    reading = tool.Reading(output["size"], output["frames"][0]["lines"])

    def find(self, form):
        return tool.find(form, self.reading, "place", "board.png")[0]

    def test_whitespace(self):
        # Given text written without its spaces
        # When it is found
        rect = self.find({"text": "Flatwhite"})

        # Then the line that holds it with spaces matches
        self.assertEqual(rect, [80.000001, 213, 212, 23])

    def test_ambiguous(self):
        # Given text two lines contain
        # When it is found without nth
        with self.assertRaises(tool.Stop) as raised:
            self.find({"text": "Total"})

        # Then it stops and lists both with their rectangles
        message = str(raised.exception)
        self.assertIn("[77.792892, 393, 162.414215, 23]  Total 10.50", message)
        self.assertIn("[77.795659, 483, 238.387482, 23]  Total saved 1.00", message)

    def test_nth(self):
        # Given text two lines contain
        # When the second is asked for with padding
        rect = self.find({"text": "Total", "nth": 1, "padding": 8})

        # Then it is the second in ocr's order, grown on every side
        self.assertEqual(rect, [69.795659, 475, 254.387482, 39])

    def test_no_match(self):
        # Given text no line contains, and an nth past the matches
        # When each is found
        # Then each stops naming the text, the nth and the media
        with self.assertRaises(tool.Stop) as raised:
            self.find({"text": "Espresso"})
        self.assertIn('"Espresso" (no nth) matches no recognised line in board.png', str(raised.exception))
        with self.assertRaises(tool.Stop) as raised:
            self.find({"text": "Total", "nth": 2})
        self.assertIn('"Total" nth 2 is past the 2 recognised lines that contain it in board.png', str(raised.exception))

    def test_range(self):
        # Given a range from one line to another
        # When it is found
        rect = self.find({"from": "Flat white", "to": "Total 10", "padding": 12})

        # Then it covers both and every line whose centre lies between them, grown by the padding
        self.assertEqual(rect, [65.792892, 201, 258.207108, 227])

    def test_aspect_ratio(self):
        # Given a line of the 1280 by 720 board, padded by 8 to [69.792892, 385, 178.414215, 39]
        # When it is grown to a landscape ratio and to a portrait one
        landscape = self.find({"text": "Total 10", "padding": 8, "aspectRatio": [16, 9]})
        portrait = self.find({"text": "Total 10", "padding": 8, "aspectRatio": [9, 16]})

        # Then each keeps the padded width, grows its height about the centre to the ratio and holds the text
        self.assertEqual(landscape, [69.792892, 354.321002, 178.414215, 100.357996])
        self.assertEqual(portrait, [69.792892, 245.909587, 178.414215, 317.180827])

    def test_aspect_ratio_slides_inside(self):
        # Given the top line, whose portrait rectangle about its centre reaches above the picture, and a line whose
        # padding reaches past the left edge
        top = self.find({"text": "Receipt", "aspectRatio": [9, 16]})
        edge = self.find({"text": "Flat white", "padding": 90, "aspectRatio": [1, 1]})

        # When each is grown, Then it slides down to the top edge, and the part inside the picture is grown
        self.assertEqual(top, [83.274157, 0, 237.365555, 421.983209])
        self.assertEqual(edge, [0, 33.5, 382.000001, 382.000001])

    def test_aspect_ratio_too_wide(self):
        # Given lines from the top of the board to its bottom, padded
        # When they are grown to a ratio the board cannot hold around them
        with self.assertRaises(tool.Stop) as raised:
            self.find({"from": "Receipt", "to": "Total saved", "padding": 8, "aspectRatio": [16, 1]})

        # Then it stops naming the picture, its size, the ratio and the padded text
        self.assertIn("place: board.png is 1280x720, which holds no rectangle of aspect ratio 16:1 around", str(raised.exception))
        self.assertIn("the padded text inside it", str(raised.exception))

    def test_aspect_ratio_form(self):
        # Given aspect ratios written as a number, a list of one, and with a part at 0
        # When each request is checked, Then each stops naming the form
        for ratio in (1.78, [16], [16, 0], [16, True]):
            with self.assertRaises(tool.Stop) as raised:
                tool.check_text_form({"tool": "frames/find-text", "text": "Total", "aspectRatio": ratio}, "place")
            self.assertEqual(str(raised.exception), "place: aspectRatio is [w, h], two numbers above 0")


class Places(Case):
    """Documents of `fixtures/places.json`, each with the frames commands the tool ran on it in
    `fixtures/places.calls.json`."""

    board = "/media/board.png"
    documents = fixture("places.json")
    calls = fixture("places.calls.json")

    def place(self, name):
        return self.stop(copy.deepcopy(self.documents[name]), self.calls[name])

    def test_unparented(self):
        # Given an unparented shape that names text
        # When the tool runs
        message = self.place("unparented")

        # Then it stops, since its timeline entry reports its space as output pixels
        self.assertIn("storyline[0]#b.connected[0]: area: the place is not in a medium's pixels", message)
        self.assertIn("it is written in output pixels", message)

    def test_title_mask(self):
        # Given a title whose mask names text
        # When the tool runs
        message = self.place("title_mask")

        # Then it stops, since its entry reports its own space as its text box
        self.assertIn("mask.area: the place is not in a medium's pixels", message)
        self.assertIn("it is written in the box of storyline[0]#b.connected[0]", message)

    def test_parent_refused_by_space(self):
        # Given a shape parented to a title, and one parented to a solid
        # When the tool runs on each
        title = self.place("parent_title")
        solid = self.place("parent_solid")

        # Then each stops on the space its entry reports, the title's box and output pixels
        self.assertIn("storyline[0]#b.connected[1]: area: the place is not in a medium's pixels", title)
        self.assertIn("it is written in the box of storyline[0]#b.connected[0]#t", title)
        self.assertNotIn("clip's area", title)
        self.assertIn("storyline[0]#s.connected[0]: area: the place is not in a medium's pixels", solid)
        self.assertIn("it is written in output pixels", solid)

    def test_parent_shape(self):
        # Given the parent title case with its parent written as a rect placed by width and height, whose box timeline
        # reports as it reports the title's, and the child's area or point naming text
        calls = copy.deepcopy(self.calls["parent_title"])
        parent = next(call for call in calls if call["arguments"][0] == "timeline")["output"]["clips"][0]
        parent["kind"] = "rect"
        document = copy.deepcopy(self.documents["parent_title"])
        connected = document["storyline"][0]["connected"]
        connected[0] = {"id": "t", "parent": "b", "kind": "rect", "width": 200, "height": 80, "position": [10, 10]}
        pointed = copy.deepcopy(document)
        pointed["storyline"][0]["connected"][1] = {"parent": "t", "kind": "title", "text": "y", "style": "title", "anchor": "left",
            "position": {"area": {"tool": "frames/find-text", "text": "Total"}, "point": "bottom-right"}}

        # When the tool runs on each
        area = self.stop(document, calls)
        point = self.stop(pointed, calls)

        # Then each stops naming the parent's box and how the place is written as the parent's clip area
        self.assertIn("it is written in the box of storyline[0]#b.connected[0]#t, a rect placed by width and height, "
                      'so write the place as that clip\'s area: {"clip": "t"}', area)
        self.assertIn('write the place as that clip\'s area: {"area": {"clip": "t"}, "point": "bottom-right"}', point)

    def test_parent_corner_pin(self):
        # Given a shape parented to a clip with a corner pin, which is parented to a still
        document = copy.deepcopy(self.documents["parent_corner_pin"])

        # When the tool runs
        result = self.run_document(document, self.calls["parent_corner_pin"])

        # Then it is found in the still's pixels, the space the corner pin is written in, as its entry reports
        area = result["storyline"][0]["connected"][1]["area"]
        self.assertEqual(area, [77.795659, 483, 238.387482, 23])
        self.assertEqual(self.commands("ocr"), [["ocr", self.board, "--json"]])

    def test_other_requests_only(self):
        # Given a document whose only requests are for another tool, one with a frames/find-text request as its argument,
        # and an area written as text without a tool
        document = {"kind": "sequence", "storyline": [{"id": "b", "kind": "media", "media": self.board, "duration": 2, "connected": [
            {"parent": "b", "kind": "rect", "area": [0, 0, 10, 10], "track": {"tool": "frames/track-motion", "target": "area"}},
            {"parent": "b", "kind": "rect", "area": [0, 0, 10, 10],
             "track": {"tool": "frames/track-motion", "target": {"tool": "frames/find-text", "text": "Total"}}},
            {"parent": "b", "kind": "rect", "area": {"text": "Total"}}
        ]}]}

        # When the tool runs
        result = self.run_document(copy.deepcopy(document), [])

        # Then the document is printed as written and frames is not run, so frames stops on what is not its own
        self.assertEqual(result, document)
        self.assertEqual(Replay.log, [])

    def test_request_where_no_area_stands(self):
        # Given a frames/find-text request as a clip's track
        document = {"kind": "sequence", "storyline": [{"id": "b", "kind": "media", "media": self.board, "duration": 2, "connected": [
            {"parent": "b", "kind": "rect", "area": [0, 0, 10, 10], "track": {"tool": "frames/find-text", "text": "Total"}}
        ]}]}

        # When the tool runs
        message = self.stop(document)

        # Then it stops, since the request stands where no area does
        self.assertIn("storyline[0]#b.connected[0]: track: a frames/find-text request stands where an area does", message)
        self.assertEqual(Replay.log, [])

    def test_vertex_point(self):
        # Given a path and a path mask whose vertices stand at points of requested areas, and a corner pin's point
        request = {"tool": "frames/find-text", "text": "Total"}
        clip = tool.Clip({"parent": "b", "kind": "path", "points": [[0, 0], {"vertex": {"area": request, "point": "right"}}],
                          "mask": {"kind": "path", "points": [[0, 0], [10, 0], {"vertex": {"area": request, "point": "top"}, "inTangent": [1, 0]}]},
                          "cornerPin": [[0, 0], {"area": request, "point": "top-right"}, [10, 10], [0, 10]]}, "place")

        # When the requests of the clip are collected
        found = tool.text_forms(clip)

        # Then each is found as the area of its point, a vertex's under its `vertex`
        self.assertEqual(sorted(entry.path for entry in found), ["cornerPin[1].area", "mask.points[2].vertex.area", "points[1].vertex.area"])

    def test_area_point_written_as_vertex(self):
        # Given a path whose points hold a point of a requested area written in place of a vertex object
        document = {"kind": "sequence", "storyline": [{"id": "b", "kind": "media", "media": self.board, "duration": 2, "connected": [
            {"parent": "b", "kind": "path", "points": [[0, 0], {"area": {"tool": "frames/find-text", "text": "Total"}, "point": "right"}]}
        ]}]}

        # When the tool runs
        message = self.stop(document)

        # Then it stops, since an object in points is a vertex and the request stands where no area does
        self.assertIn("storyline[0]#b.connected[0]: points[1].area: a frames/find-text request stands where an area does", message)
        self.assertEqual(Replay.log, [])

    def test_probe_fills_other_requests(self):
        # Given a document with requests for another tool in an area, a mask's area and a track, and one in a point
        document = {"kind": "sequence", "storyline": [{"id": "b", "kind": "media", "media": self.board, "duration": 2, "connected": [
            {"parent": "b", "kind": "rect", "area": {"tool": "other", "name": "box"},
             "mask": {"kind": "rect", "area": {"tool": "other", "name": "hole"}},
             "track": {"tool": "frames/track-motion", "target": "area"}}
        ]}]}
        pointed = copy.deepcopy(document)
        pointed["storyline"][0]["connected"][0]["position"] = {"tool": "other", "name": "pin"}

        # When the document frames is asked about is written
        probe = tool.probe_document(document)

        # Then each area holds a placeholder rectangle, the track request is gone, and the document is as written
        clip = probe["storyline"][0]["connected"][0]
        self.assertEqual((clip["area"], clip["mask"]["area"], "track" in clip), (tool.PLACEHOLDER, tool.PLACEHOLDER, False))
        self.assertEqual(document["storyline"][0]["connected"][0]["area"], {"tool": "other", "name": "box"})

        # And a request where it has no value to stand in stops, naming its tool
        with self.assertRaises(tool.Stop) as raised:
            tool.probe_document(pointed)
        self.assertIn('storyline[0]#b.connected[0]: position: a request for "other" stands where frames/find-text has no value', str(raised.exception))

    def test_compound(self):
        # Given a crop that names text inside a compound clip
        document = {"kind": "sequence", "storyline": [{"kind": "media", "media": {"kind": "sequence", "storyline": [
            {"id": "b", "kind": "media", "media": self.board, "duration": 2, "crop": {"tool": "frames/find-text", "text": "Total"}}
        ]}}]}

        # When the tool runs
        message = self.stop(document)

        # Then it stops naming the place inside the nested document
        self.assertIn("storyline[0].media.storyline[0]#b: crop", message)
        self.assertIn("inside a compound clip", message)

    def test_mixed_form(self):
        # Given a frames/find-text request that mixes its text with a clip area's key
        document = {"kind": "sequence", "storyline": [{"id": "b", "kind": "media", "media": self.board, "duration": 2, "connected": [
            {"parent": "b", "kind": "rect", "area": {"tool": "frames/find-text", "text": "Total", "clip": "b"}}
        ]}]}

        # When the tool runs
        message = self.stop(document)

        # Then it stops on the unknown key
        self.assertIn('unknown key "clip" in a frames/find-text request', message)


class Reading(unittest.TestCase):
    def test_ocr_arguments(self):
        # Given frames whose report records what it is asked
        asked = []
        frames = tool.Frames("frames", ["--ocr", "vision"])
        frames.report = lambda arguments: asked.append(arguments) or {"size": [612, 792], "frames": [{"time": 0, "lines": []}]}

        # When a page is read twice in a colour space with languages
        page = tool.Picture("/media/deck.pdf", None, 3, None)
        frames.ocr(page, "display-p3", "ko-KR,en-US")
        frames.ocr(page, "display-p3", "ko-KR,en-US")

        # Then it is read once, with the page, the colour space and the languages
        self.assertEqual(asked, [[
            "ocr", "/media/deck.pdf", "--json", "--page", "3", "--color-space", "display-p3", "--languages", "ko-KR,en-US"
        ]])

    def test_failed_command(self):
        # Given a frames that stops on every command, run with a theme and without
        directory = tempfile.mkdtemp(prefix="find-text-test-")
        self.addCleanup(shutil.rmtree, directory, True)
        executable = os.path.join(directory, "frames")
        with open(executable, "w", encoding="utf-8") as file:
            file.write('#!/bin/sh\necho \'frames: shape style "outline" is not in shapes\' >&2\nexit 1\n')
        os.chmod(executable, 0o755)

        # When each runs timeline
        messages = []
        for options in (["--theme", "shorts/shorts", "--ocr", "vision"], []):
            with self.assertRaises(tool.Stop) as raised:
                tool.Frames(executable, options).report(["timeline", "/tmp/a b/document.json", "--json"])
            messages.append(str(raised.exception))

        # Then each names the command line it ran, its global options included, and what frames said
        self.assertEqual(messages, [
            f"{executable} --theme shorts/shorts --ocr vision timeline '/tmp/a b/document.json' --json failed: "
            'frames: shape style "outline" is not in shapes',
            f"{executable} timeline '/tmp/a b/document.json' --json failed: frames: shape style \"outline\" is not in shapes"
        ])

    def test_options(self):
        # Given the global options frames passes before the tool's arguments
        # When they are parsed
        options, document, languages, report = tool.parse(["--theme", "demo/dark", "/a/b.json", "--languages", "en-US"])

        # Then the global options are kept for every frames command and the languages for ocr
        self.assertEqual(options, ["--theme", "demo/dark"])
        self.assertEqual(document, "/a/b.json")
        self.assertEqual(languages, "en-US")
        self.assertIsNone(report)

    def test_report_path(self):
        # Given a report path with an extension in upper case
        # When it is parsed
        report = tool.parse(["/a/b.json", "--report", "/a/b.report.JSON"])[3]

        # Then it is kept
        self.assertEqual(report, "/a/b.report.JSON")

        # And a relative path, another extension and the document's own path each stop before the document is read
        for path, message in (
            ("b.report.json", '--report "b.report.json" is not an absolute path, and paths are absolute'),
            ("/a/b.txt", '--report "/a/b.txt": a report is written to a .json file'),
            ("/a/b.json", '--report "/a/b.json": the report would be written over the document')
        ):
            with self.assertRaises(tool.Stop) as raised:
                tool.parse(["/nowhere/b.json" if path == "b.report.json" else "/a/b.json", "--report", path])
            self.assertEqual(str(raised.exception), message)

    def test_without_frames(self):
        # Given a document with a request, and no frames executable given
        document = fixture("still.json")
        path = os.path.join(tempfile.mkdtemp(prefix="find-text-test-"), "document.json")
        self.addCleanup(shutil.rmtree, os.path.dirname(path), True)
        with open(path, "w", encoding="utf-8") as file:
            json.dump(document, file)

        # When the tool runs
        with self.assertRaises(tool.Stop) as raised:
            tool.run([path], None)

        # Then it stops, since only frames gives the executable it runs
        self.assertEqual(str(raised.exception), "FRAMES_EXECUTABLE is not set: the tool is run by frames, as frames frames/find-text")

    def test_write_report(self):
        # Given a request filled
        directory = tempfile.mkdtemp(prefix="find-text-test-")
        self.addCleanup(shutil.rmtree, directory, True)
        path = os.path.join(directory, "report.json")
        filled = [{"place": "clips[0]", "key": "area", "rect": [1, 2, 3, 4]}]

        # When the report is written
        tool.write_report(path, filled)

        # Then its first key names the tool and its version, the version of the pack frames, and it holds the requests
        with open(path, encoding="utf-8") as file:
            text = file.read()
        self.assertTrue(text.startswith('{\n  "frames/find-text": "0.1.0",'))
        self.assertEqual(json.loads(text), {"frames/find-text": "0.1.0", "requests": filled})


if __name__ == "__main__":
    unittest.main()
