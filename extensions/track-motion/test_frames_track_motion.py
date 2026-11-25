"""Checks frames-track-motion against frames output recorded in `fixtures/`, so it runs without frames.

Run from the repository root: python3 -m unittest discover -s extensions/track-motion

`fixtures/video.json` and `fixtures/keyframed.json` name their media as `/media/moving.mp4`, `/media/board.png` and `/media/frames`, and each
`*.calls.json` holds the frames commands the extension ran on it with what frames printed, the document it asks about
written as `<document>`. `moving.mp4` is a 3 second 640 by 360 video at 25 frames a second, rendered by frames, of a
title `Total 42,000` and an orange card with a white stroke moving right over a dark solid, `frames` an image sequence
of its frames, read at 25 frames a second, and `board.png` a still. The tracker is the default `point` tracker, which
loses the card at 2.04 seconds.
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
loader = importlib.machinery.SourceFileLoader("frames_track_motion", os.path.join(HERE, "frames-track-motion"))
spec = importlib.util.spec_from_loader("frames_track_motion", loader)
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
        directory = tempfile.mkdtemp(prefix="frames-track-motion-test-")
        self.addCleanup(shutil.rmtree, directory, True)
        path = os.path.join(directory, "document.json")
        with open(path, "w", encoding="utf-8") as file:
            json.dump(document, file)
        return extension.run([path, *options])

    def stop(self, document, calls=None):
        with self.assertRaises(extension.Stop) as raised:
            self.run_document(document, calls or [])
        return str(raised.exception)

    def commands(self, name):
        return [arguments for arguments in Replay.log if arguments[0] == name]


class Recorded(Case):
    def setUp(self):
        super().setUp()
        self.result = self.run_document(fixture("video.json"), fixture("video.calls.json"))
        self.clips = {clip["id"]: clip for clip in self.result["storyline"][0]["connected"]}

    def test_video(self):
        # Given a shot with a box, a title, a corner pin and a rect asking to be followed, and an image sequence
        # When the extension runs
        # Then every request is the track data frames printed, and nothing else of the document changes
        self.assertEqual(self.result, fixture("video.expected.json"))

    def test_own_area_on_instant(self):
        # Given a box with `"track": true` from 0.4 seconds
        box = self.clips["box"]["track"]

        # Then its own area is followed from the frame its instant shows, to the first and to the last frame tracked
        self.assertEqual(box["time"], 0.4)
        on_instant = box["frames"][[frame["time"] for frame in box["frames"]].index(0.4)]
        self.assertEqual(on_instant["quad"], [[124, 202], [252, 202], [252, 290], [124, 290]])
        self.assertIn(["timeline", "<document>", "--at", "0.4", "--json"], Replay.log)
        tracks = [arguments for arguments in self.commands("track") if "[124, 202, 128, 88]" in arguments and "/media/moving.mp4" in arguments]
        self.assertEqual([arguments[arguments.index("--to") + 1] for arguments in tracks], ["0", "2.96"])
        times = [frame["time"] for frame in box["frames"]]
        self.assertEqual(times, sorted(set(times)))
        self.assertEqual((times[0], times[-1], len(times)), (0, 2, 51))

    def test_area_request(self):
        # Given a title whose `track` is an area, the same one the box writes
        # Then it is followed as the box's area is, with one run of frames track for both
        self.assertEqual(self.clips["label"]["track"], self.clips["box"]["track"])
        self.assertEqual(len(self.commands("track")), 8)

    def test_corner_pin(self):
        # Given a clip with a corner pin and `{"time": 1}`
        pin = self.clips["pin"]["track"]

        # Then its quadrilateral is followed with --quad from the frame at media second 1
        self.assertEqual(pin["time"], 1)
        self.assertIn(
            ["track", "/media/moving.mp4", "--at", "1", "--quad", "[[192, 192], [328, 194], [326, 288], [194, 286]]", "--to", "0"],
            Replay.log
        )
        self.assertEqual(pin["frames"][[frame["time"] for frame in pin["frames"]].index(1)]["quad"], [[192, 192], [328, 194], [326, 288], [194, 286]])

    def test_time_and_area(self):
        # Given a rect with `{"time": 2, "area": a}`
        total = self.clips["total"]["track"]

        # Then the area is followed from the frame at media second 2, and no instant is asked for
        self.assertEqual(total["time"], 2)
        self.assertEqual(self.commands("timeline"), [["timeline", "<document>", "--json"], ["timeline", "<document>", "--at", "0.4", "--json"]])

    def test_track_data_kept(self):
        # Given track data already written
        # Then it is kept as written
        self.assertEqual(self.clips["kept"]["track"], fixture("video.json")["storyline"][0]["connected"][4]["track"])

    def test_image_sequence(self):
        # Given an image sequence's own crop with `{"time": 0.4}`
        sequence = self.result["storyline"][1]["track"]

        # Then it is followed in the directory at the rate its entry reports, as --fps
        self.assertEqual(sequence["time"], 0.4)
        self.assertIn(
            ["track", "/media/frames", "--fps", "25", "--at", "0.4", "--area", "[124, 202, 128, 88]", "--to", "2"],
            Replay.log
        )

    def test_probe_without_track(self):
        # Then frames is asked about the document without any `track`
        self.assertEqual(Replay.log[0], ["--version"])
        self.assertEqual(self.commands("evaluate") + self.commands("render") + self.commands("resolve"), [])


class Keyframed(Case):
    """`fixtures/keyframed.json`: a shot after a half second solid, from media second 0.2 at half speed, so its clock
    is `origin 0.1, speed 0.5`, with a box and a corner pin whose keyframes write their targets."""

    def setUp(self):
        super().setUp()
        self.result = self.run_document(fixture("keyframed.json"), fixture("keyframed.calls.json"))
        self.clips = {clip["id"]: clip for clip in self.result["storyline"][1]["connected"]}

    def test_keyframed(self):
        # Given keyframed targets with `"track": true`
        # When the extension runs
        # Then every request is the track data frames printed, and nothing else of the document changes
        self.assertEqual(self.result, fixture("keyframed.expected.json"))

    def test_first_keyframe_on_its_clock(self):
        # Given a box whose first keyframe writes its area at clip time 0.6
        box = self.clips["box"]["track"]

        # Then the frame is the one timeline --at shows at 0.1 + 0.6 / 0.5, and the first keyframe's area is followed
        self.assertIn(["timeline", "<document>", "--at", "1.3", "--json"], Replay.log)
        self.assertEqual(box["time"], 0.6)
        self.assertIn(
            ["track", "/media/moving.mp4", "--at", "0.6", "--area", "[148, 200, 128, 88]", "--to", "0.2"],
            Replay.log
        )
        self.assertEqual(box["frames"][[frame["time"] for frame in box["frames"]].index(0.6)]["quad"], [[148, 200], [276, 200], [276, 288], [148, 288]])

    def test_earliest_keyframe_written_last(self):
        # Given a corner pin keyframed at clip time 1, and twice at 0.6, written out of time order
        # Then the quadrilateral followed is the one written last at the earliest time
        self.assertEqual(self.clips["pin"]["track"]["time"], 0.6)
        self.assertIn(
            ["track", "/media/moving.mp4", "--at", "0.6", "--quad", "[[148, 200], [276, 200], [276, 288], [148, 288]]", "--to", "2.96"],
            Replay.log
        )


class Places(Case):
    """Documents of `fixtures/places.json`, each with the frames commands the extension ran on it in
    `fixtures/places.calls.json`."""

    documents = fixture("places.json")
    calls = fixture("places.calls.json")

    def place(self, name):
        return self.stop(copy.deepcopy(self.documents[name]), self.calls[name])

    def test_untracked(self):
        # Given an unparented rect asking to be followed
        # Then it stops, since its entry reports `tracked` as null
        self.assertEqual(self.place("unparented"), "clips[0]: track: timeline reports no video or image sequence for its track to follow")

    def test_no_target(self):
        # Given a title with `"track": true`, which writes nothing in its parent's media pixels
        # Then it stops, since it must name its target
        self.assertIn("writes no area, corner pin, crop or mask in the media pixels of storyline[0]#shot", self.place("no_target"))

    def test_two_targets(self):
        # Given a storyline clip with a crop and a mask, both in its own media pixels
        # Then `true` stops, since it must name its target
        self.assertIn("the clip writes its crop and mask in the media pixels it follows", self.place("two_targets"))

    def test_mask(self):
        # Given a storyline clip whose one target is its mask
        # Then it stops, since no report gives the bounds of a mask
        self.assertIn("it follows the bounds of the clip's masks, which no report gives", self.place("mask_target"))

    def test_keyframed_time(self):
        # Given a keyframed area with `{"time": t}`
        # Then it stops, since no keyframe is written on the frame t names
        self.assertIn("none is written on the frame time names", self.place("keyframed_time"))

    def test_keyframe_without_time(self):
        # Given a keyframed area with `true` whose keyframe has no number at
        document = copy.deepcopy(self.documents["keyframed_time"])
        clip = document["storyline"][0]["connected"][0]
        clip["track"] = True
        clip["keyframes"][1]["at"] = "1"

        # Then it stops, naming the keyframe
        self.assertIn("storyline[0]#shot.connected[0]: keyframes[1] needs a number at", self.stop(document, self.calls["keyframed_time"]))

    def test_text_and_clip_targets(self):
        # Given a target named by its text and one named as another clip's box
        # Then each stops before frames runs
        self.assertIn("written as a rectangle by `frames find-text`", self.place("text_target"))
        self.assertIn("a clip area is the box of another clip", self.place("clip_target"))
        self.assertEqual(Replay.log, [])

    def test_unknown_key(self):
        # Given a request with a key it does not take
        # Then it stops, naming the key
        self.assertIn('unknown key "padding" in a request. Allowed: area, time', self.place("bad_key"))


class Arguments(Case):
    def test_no_request(self):
        # Given a document without a request
        document = {"kind": "sequence", "storyline": [{"media": "/media/moving.mp4"}]}

        # When the extension runs
        result = self.run_document(copy.deepcopy(document), [])

        # Then it is printed as it is, and frames is not run
        self.assertEqual(result, document)
        self.assertEqual(Replay.log, [])

    def test_nested(self):
        # Given a request inside a compound clip
        document = {"kind": "sequence", "storyline": [{"media": {"kind": "sequence", "storyline": [
            {"media": "/media/moving.mp4", "track": True}
        ]}}]}

        # Then it stops, naming the place inside
        self.assertIn("storyline[0].media.storyline[0]: track: it is inside a compound clip", self.stop(document))

    def test_relative_path(self):
        # Then a relative document path stops
        with self.assertRaises(extension.Stop) as raised:
            extension.parse(["edit.json"])
        self.assertIn("is not an absolute path", str(raised.exception))

    def test_global_options(self):
        # Then the global options of frames are passed on
        self.assertEqual(extension.parse(["--tracker", "planar", "/abs/edit.json"]), (["--tracker", "planar"], "/abs/edit.json"))


if __name__ == "__main__":
    unittest.main()
