"""Checks frames-track-motion against frames output recorded in `fixtures/`, so it runs without frames.

Run from the repository root: python3 -m unittest discover -s extensions/track-motion

`fixtures/video.json` and `fixtures/keyframed.json` name their media as `/media/moving.mp4`, `/media/board.png` and `/media/frames`, and each
`*.calls.json` holds the frames commands the extension ran on it with what frames printed, the document it asks about
written as `<document>`. `moving.mp4` is a 3 second 640 by 360 video at 25 frames a second, rendered by frames, of a
title `Total 42,000` and an orange card with a white stroke moving right over a dark solid, `frames` an image sequence
of its frames, read at 25 frames a second, and `board.png` a still. The tracker is the default `point` tracker, which
loses the card at 2.04 seconds. The video fixture holds a `find-text` request beside the `track-motion` ones, which the
extension leaves as written.
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
        # Given a shot with a box, a title, a corner pin and a rect whose tracks are requests, a find-text request, and
        # an image sequence
        # When the extension runs
        # Then every track request is the track data frames printed, and nothing else of the document changes
        self.assertEqual(self.result, fixture("video.expected.json"))

    def test_own_area_on_instant(self):
        # Given a box from 0.4 seconds whose track request names its area as the target
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
        # Given a title whose track request's target is an area, the same one the box writes
        # Then it is followed as the box's area is, with one run of frames track for both
        self.assertEqual(self.clips["label"]["track"], self.clips["box"]["track"])
        self.assertEqual(len(self.commands("track")), 8)

    def test_corner_pin(self):
        # Given a clip whose track request names its corner pin as the target, with time 1
        pin = self.clips["pin"]["track"]

        # Then its quadrilateral is followed with --quad from the frame at media second 1
        self.assertEqual(pin["time"], 1)
        self.assertIn(
            ["track", "/media/moving.mp4", "--at", "1", "--quad", "[[192, 192], [328, 194], [326, 288], [194, 286]]", "--to", "0"],
            Replay.log
        )
        self.assertEqual(pin["frames"][[frame["time"] for frame in pin["frames"]].index(1)]["quad"], [[192, 192], [328, 194], [326, 288], [194, 286]])

    def test_time_and_area(self):
        # Given a rect whose track request's target is an area, with time 2
        total = self.clips["total"]["track"]

        # Then the area is followed from the frame at media second 2, and no instant is asked for
        self.assertEqual(total["time"], 2)
        self.assertEqual(self.commands("timeline"), [["timeline", "<document>", "--json"], ["timeline", "<document>", "--at", "0.4", "--json"]])

    def test_track_data_kept(self):
        # Given track data already written, on a rect whose area is a find-text request
        written = fixture("video.json")["storyline"][0]["connected"][4]

        # Then both are kept as written
        self.assertEqual((self.clips["kept"]["track"], self.clips["kept"]["area"]), (written["track"], written["area"]))

    def test_image_sequence(self):
        # Given an image sequence whose track request names its own crop as the target, with time 0.4
        sequence = self.result["storyline"][1]["track"]

        # Then it is followed in the directory at the rate its entry reports, as --fps
        self.assertEqual(sequence["time"], 0.4)
        self.assertIn(
            ["track", "/media/frames", "--fps", "25", "--at", "0.4", "--area", "[124, 202, 128, 88]", "--to", "2"],
            Replay.log
        )

    def test_probe_without_requests(self):
        # Then frames is asked only for reports, about the document with a value in the place of each request
        self.assertEqual(Replay.log[0], ["--version"])
        self.assertEqual(self.commands("evaluate") + self.commands("render") + self.commands("resolve"), [])
        probe = extension.probe_document(fixture("video.json"))
        clips = {clip["id"]: clip for clip in probe["storyline"][0]["connected"]}
        self.assertEqual(["track" in clip for clip in clips.values()], [False, False, False, False, True])
        self.assertEqual(clips["kept"]["area"], extension.PLACEHOLDER)


class Keyframed(Case):
    """`fixtures/keyframed.json`: a shot after a half second solid, from media second 0.2 at half speed, so its clock
    is `origin 0.1, speed 0.5`, with a box and a corner pin whose keyframes write their targets."""

    def setUp(self):
        super().setUp()
        self.result = self.run_document(fixture("keyframed.json"), fixture("keyframed.calls.json"))
        self.clips = {clip["id"]: clip for clip in self.result["storyline"][1]["connected"]}

    def test_keyframed(self):
        # Given track requests that name keyframed keys as their targets
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

    def test_unwritten_target(self):
        # Given a title and a storyline clip whose track requests name an area neither writes
        # Then each stops, naming the key
        self.assertEqual(
            self.place("no_target"),
            "storyline[0]#shot.connected[0]: track (area): the clip writes no area, which the request names as its target"
        )
        self.assertIn("storyline[0]#shot: track (area): the clip writes no area", self.place("two_targets"))

    def test_target_outside_followed_pixels(self):
        # Given a storyline clip whose track request names its corner pin, which is written in output pixels
        # Then it stops, naming the space the key is written in
        self.assertEqual(
            self.place("pin_output"),
            "storyline[0]#shot: track (cornerPin): the clip writes its cornerPin in output pixels, not in the media pixels "
            "of storyline[0]#shot, which its track follows"
        )

    def test_mask(self):
        # Given a storyline clip whose one target is its mask
        # Then it stops, since no report gives the bounds of a mask
        self.assertIn("it follows the bounds of the clip's masks, which no report gives", self.place("mask_target"))

    def test_keyframed_time(self):
        # Given a track request that names a keyframed area, with a time
        # Then it stops, since no keyframe is written on the frame t names
        self.assertIn("none is written on the frame time names", self.place("keyframed_time"))

    def test_keyframe_without_time(self):
        # Given a track request that names a keyframed area, whose keyframe has no number at
        document = copy.deepcopy(self.documents["keyframed_time"])
        clip = document["storyline"][0]["connected"][0]
        del clip["track"]["time"]
        clip["keyframes"][1]["at"] = "1"

        # Then it stops, naming the keyframe
        self.assertIn("storyline[0]#shot.connected[0]: keyframes[1] needs a number at", self.stop(document, self.calls["keyframed_time"]))

    def test_request_and_clip_targets(self):
        # Given a target that is a find-text request and one named as another clip's box
        # Then each stops before frames runs, the first since a request's arguments are values
        self.assertIn('track.target: a request\'s arguments are values, and this one holds a request for "find-text"', self.place("text_target"))
        self.assertIn("a clip area is the box of another clip", self.place("clip_target"))
        self.assertEqual(Replay.log, [])

    def test_unfilled_target(self):
        # Given a track request whose target key holds a find-text request, statically and in a keyframe
        document = copy.deepcopy(self.documents["clip_target"])
        clip = document["storyline"][0]["connected"][1]
        clip["area"] = {"tool": "find-text", "text": "Total"}
        clip["track"] = {"tool": "track-motion", "target": "area"}
        keyframed = copy.deepcopy(document)
        del keyframed["storyline"][0]["connected"][1]["area"]
        keyframed["storyline"][0]["connected"][1]["keyframes"] = [
            {"at": 0, "area": [0, 0, 10, 10]}, {"at": 1, "area": {"tool": "find-text", "text": "Total"}}
        ]

        # Then each stops before frames runs, naming the request that is not filled
        self.assertEqual(
            self.stop(document),
            'storyline[0]#shot.connected[1]: track: its target "area" holds a request for "find-text" at area, which is not '
            'filled yet: run frames find-text first, since the target is the value it finds'
        )
        self.assertIn('holds a request for "find-text" at keyframes[1].area', self.stop(keyframed))
        self.assertEqual(Replay.log, [])

    def test_target_forms(self):
        # Given requests without a target, with a target that names no key a target lies in, and with a time that is
        # not a number
        document = copy.deepcopy(self.documents["bad_key"])
        clip = document["storyline"][0]["connected"][0]
        messages = []
        for track in ({"tool": "track-motion"}, {"tool": "track-motion", "target": "position"},
                      {"tool": "track-motion", "target": "area", "time": "1"}):
            clip["track"] = track
            messages.append(self.stop(copy.deepcopy(document)))

        # Then each stops, naming what is wrong
        self.assertIn("a track-motion request names its target", messages[0])
        self.assertIn('track.target: "position" is none of the clip\'s own keys a target lies in: area, cornerPin, crop, mask', messages[1])
        self.assertIn("track.time: the media time of the frame the target is written on is a number", messages[2])

    def test_unknown_key(self):
        # Given a request with a key it does not take
        # Then it stops, naming the key
        self.assertIn('unknown key "padding" in a track-motion request. Allowed: target, time, tool', self.place("bad_key"))


class Arguments(Case):
    def test_no_request(self):
        # Given a document whose track is a boolean, and one whose only request is for another tool
        document = {"kind": "sequence", "storyline": [{"media": "/media/moving.mp4", "track": True, "connected": [
            {"shape": "rect", "area": {"tool": "find-text", "text": "Total"}, "track": {"tool": "other", "target": "area"}}
        ]}]}

        # When the extension runs
        result = self.run_document(copy.deepcopy(document), [])

        # Then it is printed as it is, and frames is not run, so frames stops on what is not its own
        self.assertEqual(result, document)
        self.assertEqual(Replay.log, [])

    def test_nested(self):
        # Given a request inside a compound clip
        document = {"kind": "sequence", "storyline": [{"media": {"kind": "sequence", "storyline": [
            {"media": "/media/moving.mp4", "track": {"tool": "track-motion", "target": [0, 0, 10, 10]}}
        ]}}]}

        # Then it stops, naming the place inside
        self.assertIn("storyline[0].media.storyline[0]: track: it is inside a compound clip", self.stop(document))

    def test_misplaced(self):
        # Given a track-motion request as a clip's area
        document = {"kind": "sequence", "storyline": [{"media": "/media/moving.mp4", "connected": [
            {"shape": "rect", "area": {"tool": "track-motion", "target": [0, 0, 10, 10]}}
        ]}]}

        # Then it stops, since it stands as a clip's track
        self.assertIn("storyline[0].connected[0]: area: a track-motion request stands as a clip's track", self.stop(document))

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
