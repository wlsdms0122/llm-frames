"""Checks frames-find-text against frames output recorded in `fixtures/`, so it runs without frames.

Run from the repository root: python3 -m unittest discover -s extensions/find-text

`fixtures/still.json` and `fixtures/video.json` name their media as `/media/board.png`, `/media/clip.mp4` and
`/media/frames`, and each `*.calls.json` holds the frames commands the extension ran on them with what frames printed,
the document it asks about written as `<document>`. `board.png` is a still of six lines of text, `clip.mp4` a 4 second
video at 25 frames a second that shows `Price 4.50` at the top left before 2 seconds and `Price 6.00` at the bottom
right from 2 seconds, and `frames` an image sequence of its frames every half second, read at 2 frames a second.
"""

import copy
import importlib.machinery
import importlib.util
import json
import os
import shutil
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.join(HERE, "fixtures")
loader = importlib.machinery.SourceFileLoader("frames_find_text", os.path.join(HERE, "frames-find-text"))
spec = importlib.util.spec_from_loader("frames_find_text", loader)
extension = importlib.util.module_from_spec(spec)
loader.exec_module(extension)


def fixture(name):
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as file:
        return json.load(file)


class Replay(extension.Frames):
    """Frames that answers each command with what the real one printed for it."""

    calls = []
    log = []

    def check_version(self):
        Replay.log.append(["--version"])

    def report(self, arguments):
        arguments = ["<document>" if argument.endswith("/document.json") else argument for argument in arguments]
        Replay.log.append(arguments)
        for call in Replay.calls:
            if call["arguments"] == arguments:
                return call["output"]
        raise AssertionError(f"no recorded output for frames {' '.join(arguments)}")


class Case(unittest.TestCase):
    def setUp(self):
        self.original = extension.Frames
        extension.Frames = Replay
        Replay.log = []

    def tearDown(self):
        extension.Frames = self.original

    def run_document(self, document, calls, *options):
        Replay.calls = calls
        path = os.path.join(self.directory(), "document.json")
        with open(path, "w", encoding="utf-8") as file:
            json.dump(document, file)
        return extension.run([path, *options])

    def directory(self):
        directory = tempfile.mkdtemp(prefix="frames-find-text-test-")
        self.addCleanup(shutil.rmtree, directory, True)
        return directory

    def stop(self, document, calls=None, *options):
        with self.assertRaises(extension.Stop) as raised:
            self.run_document(document, calls or [], *options)
        return str(raised.exception)

    def commands(self, name):
        return [arguments for arguments in Replay.log if arguments[0] == name]


class Recorded(Case):
    def test_still(self):
        # Given a still under shapes, a point and a crop that name its text
        document = fixture("still.json")

        # When the extension writes the rectangles
        result = self.run_document(document, fixture("still.calls.json"))

        # Then each is the rectangle ocr reports, padding included, and the still is read once
        self.assertEqual(result, fixture("still.expected.json"))
        self.assertEqual(len(self.commands("ocr")), 1)

    def test_video(self):
        # Given a video under keyframed areas, a speed, a time remap, a picture in picture, track targets and an image
        # sequence
        document = fixture("video.json")

        # When the extension writes the rectangles
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

        # When the extension writes the rectangles
        result = self.run_document(document, fixture("video.calls.json"), "--languages", "en-US")

        # Then each is found on the frame the clip's time map shows there, which timeline --at gives
        self.assertEqual(result["clips"][2]["keyframes"][2]["area"], [699.924263, 518, 148.151474, 23])
        self.assertEqual([keyframe["area"] for keyframe in result["clips"][4]["keyframes"]], [
            [99.90329, 118, 146.19342, 23], [699.924263, 518, 148.151474, 23]
        ])
        self.assertIn(["timeline", "<document>", "--at", "12", "--json"], Replay.log)
        self.assertEqual(self.commands("evaluate") + self.commands("locate") + self.commands("probe"), [])

    def test_image_sequence(self):
        # Given an image sequence's crop and a track target at a media time on it
        result = self.run_document(fixture("video.json"), fixture("video.calls.json"), "--languages", "en-US")

        # When the image sequence is read
        sequence = result["storyline"][3]

        # Then its directory is read with ocr at the rate its media form writes, at the frame shown at its in and at
        # the track's time
        self.assertEqual(sequence["crop"], [89.90329, 108, 166.19342, 43])
        self.assertEqual(sequence["connected"][0]["track"]["area"], [699.924263, 518, 148.151474, 23])
        self.assertIn(["ocr", "/media/frames", "--json", "--fps", "2", "--at", "1", "--languages", "en-US"], Replay.log)

    def test_no_text_forms(self):
        # Given a document whose areas are rectangles
        document = {"kind": "sequence", "storyline": [{"solid": "#000000", "duration": 1}]}

        # When the extension runs
        result = self.run_document(copy.deepcopy(document), [])

        # Then the document is unchanged and frames is not run
        self.assertEqual(result, document)
        self.assertEqual(Replay.log, [])


class Matching(unittest.TestCase):
    lines = fixture("still.calls.json")
    lines = next(call for call in lines if call["arguments"][0] == "ocr")["output"]["frames"][0]["lines"]

    def find(self, form):
        return extension.find(form, self.lines, "place", "board.png")

    def test_whitespace(self):
        # Given text written without its spaces
        # When it is found
        rect = self.find({"text": "Flatwhite"})

        # Then the line that holds it with spaces matches
        self.assertEqual(rect, [80.000001, 213, 212, 23])

    def test_ambiguous(self):
        # Given text two lines contain
        # When it is found without nth
        with self.assertRaises(extension.Stop) as raised:
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
        with self.assertRaises(extension.Stop) as raised:
            self.find({"text": "Espresso"})
        self.assertIn('"Espresso" (no nth) matches no recognised line in board.png', str(raised.exception))
        with self.assertRaises(extension.Stop) as raised:
            self.find({"text": "Total", "nth": 2})
        self.assertIn('"Total" nth 2 is past the 2 recognised lines that contain it in board.png', str(raised.exception))

    def test_range(self):
        # Given a range from one line to another
        # When it is found
        rect = self.find({"from": "Flat white", "to": "Total 10", "padding": 12})

        # Then it covers both and every line whose centre lies between them, grown by the padding
        self.assertEqual(rect, [65.792892, 201, 258.207108, 227])


class Places(Case):
    board = "/media/board.png"

    def child(self, child, parent=None):
        parent = parent or {"id": "b", "media": self.board, "duration": 2}
        return {"kind": "sequence", "storyline": [dict(parent, connected=[child])]}

    def test_unparented(self):
        # Given an unparented shape that names text
        document = self.child({"shape": "rect", "fill": "#FF0000", "area": {"text": "Total"}})

        # When the extension runs
        message = self.stop(document)

        # Then it stops, since the place is in output pixels
        self.assertIn("storyline[0]#b.connected[0]: area: the place is not in a medium's pixels", message)
        self.assertIn("output pixels", message)

    def test_title_mask(self):
        # Given a title whose mask names text
        document = self.child(
            {"title": "x", "style": "title", "placement": "center", "mask": {"shape": "rect", "area": {"text": "Total"}}}
        )

        # When the extension runs
        message = self.stop(document)

        # Then it stops, since the mask is in the title's text box
        self.assertIn("mask.area: the place is not in a medium's pixels", message)
        self.assertIn("a title's mask is in its text box", message)

    def test_parent_corner_pin(self):
        # Given a shape parented to a clip with a corner pin
        document = {
            "kind": "sequence",
            "storyline": [{"id": "b", "media": self.board, "duration": 2, "connected": [
                {"id": "p", "media": self.board, "cornerPin": [[0, 0], [100, 0], [100, 100], [0, 100]]},
                {"parent": "p", "shape": "rect", "fill": "#FF0000", "area": {"text": "Total"}}
            ]}]
        }

        # When the extension runs
        message = self.stop(document)

        # Then it stops naming the parent and its corner pin
        self.assertIn("its parent storyline[0]#b.connected[0]#p has a corner pin", message)

    def test_compound(self):
        # Given a crop that names text inside a compound clip
        document = {"kind": "sequence", "storyline": [{"media": {"kind": "sequence", "storyline": [
            {"id": "b", "media": self.board, "duration": 2, "crop": {"text": "Total"}}
        ]}}]}

        # When the extension runs
        message = self.stop(document)

        # Then it stops naming the place inside the nested document
        self.assertIn("storyline[0].media.storyline[0]#b: crop", message)
        self.assertIn("inside a compound clip", message)

    def test_mixed_form(self):
        # Given an area that mixes a text form with a clip area
        document = self.child({"parent": "b", "shape": "rect", "area": {"text": "Total", "clip": "b"}})

        # When the extension runs
        message = self.stop(document)

        # Then it stops on the unknown key
        self.assertIn('unknown key "clip" in a text area', message)


class Reading(unittest.TestCase):
    def test_ocr_arguments(self):
        # Given frames whose report records what it is asked
        asked = []
        frames = extension.Frames("frames", ["--ocr", "vision"])
        frames.report = lambda arguments: asked.append(arguments) or {"frames": [{"time": 0, "lines": []}]}

        # When a page is read twice in a colour space with languages
        page = extension.Picture("/media/deck.pdf", None, 3, None)
        frames.ocr(page, "display-p3", "ko-KR,en-US")
        frames.ocr(page, "display-p3", "ko-KR,en-US")

        # Then it is read once, with the page, the colour space and the languages
        self.assertEqual(asked, [[
            "ocr", "/media/deck.pdf", "--json", "--page", "3", "--color-space", "display-p3", "--languages", "ko-KR,en-US"
        ]])

    def test_options(self):
        # Given the global options frames passes before the extension's arguments
        # When they are parsed
        options, document, languages = extension.parse(["--theme", "demo/dark", "/a/b.json", "--languages", "en-US"])

        # Then the global options are kept for every frames command and the languages for ocr
        self.assertEqual(options, ["--theme", "demo/dark"])
        self.assertEqual(document, "/a/b.json")
        self.assertEqual(languages, "en-US")


if __name__ == "__main__":
    unittest.main()
