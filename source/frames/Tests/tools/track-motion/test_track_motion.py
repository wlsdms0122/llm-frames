"""Checks the tool frames/track-motion of the pack `frames` against frames output recorded in `fixtures/`, so it runs
without frames.

Run from the repository root: python3 -m unittest discover -s source/frames/Tests/tools/track-motion

`fixtures/video.json`, `fixtures/keyframed.json` and `fixtures/targets.json` name their media as `/media/moving.mp4`, `/media/board.png` and `/media/frames`, and each
`*.calls.json` holds the frames commands the tool ran on it with what frames printed, the document it asks about
written as `<document>`. `moving.mp4` is a 3 second 640 by 360 video at 25 frames a second, rendered by frames, of a
title `Total 42,000` and an orange card with a white stroke moving right over a dark solid, `frames` an image sequence
of its frames, read at 25 frames a second, and `board.png` a still. The tracker is the default `point` tracker, which
loses the card at 2.04 seconds. The video fixture holds a `frames/find-text` request beside the `frames/track-motion` ones, which the
tool leaves as written.
"""

import copy
import importlib.machinery
import importlib.util
import json
import os
import shlex
import shutil
import stat
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.join(HERE, "fixtures")
PROGRAM = os.path.join(HERE, os.pardir, os.pardir, os.pardir, "Sources", "FramesCommand", "Resources", "packs", "frames", "tools", "track-motion", "track-motion")
# The program is one of frames' resources, which the build copies into its bundle, so no bytecode is written
# beside it.
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("frames_track_motion", PROGRAM)
spec = importlib.util.spec_from_loader("frames_track_motion", loader)
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
        Replay.calls = calls
        directory = tempfile.mkdtemp(prefix="track-motion-test-")
        self.addCleanup(shutil.rmtree, directory, True)
        path = os.path.join(directory, "document.json")
        with open(path, "w", encoding="utf-8") as file:
            json.dump(document, file)
        return tool.run([path, *options], "frames")

    def stop(self, document, calls=None):
        with self.assertRaises(tool.Stop) as raised:
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
        # Given a shot with a box, a title, a corner pin and a rect whose tracks are requests, a frames/find-text request, and
        # an image sequence
        # When the tool runs
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
        # Given a clip from 1 second whose track request names its corner pin as the target
        pin = self.clips["pin"]["track"]

        # Then its quadrilateral is followed with --quad from the frame its instant shows
        self.assertEqual(pin["time"], 1)
        self.assertIn(["timeline", "<document>", "--at", "1", "--json"], Replay.log)
        self.assertIn(
            ["track", "/media/moving.mp4", "--at", "1", "--quad", "[[192, 192], [328, 194], [326, 288], [194, 286]]", "--to", "0"],
            Replay.log
        )
        self.assertEqual(pin["frames"][[frame["time"] for frame in pin["frames"]].index(1)]["quad"], [[192, 192], [328, 194], [326, 288], [194, 286]])

    def test_area_on_instant(self):
        # Given a rect from 2 seconds whose track request's target is an area
        total = self.clips["total"]["track"]

        # Then the area is followed from the frame its instant shows, each instant asked for once
        self.assertEqual(total["time"], 2)
        self.assertEqual(
            [arguments[3] for arguments in self.commands("timeline") if "--at" in arguments],
            ["0.4", "1", "2", "3.4"]
        )

    def test_track_data_kept(self):
        # Given track data already written, on a rect whose area is a frames/find-text request
        written = fixture("video.json")["storyline"][0]["connected"][4]

        # Then both are kept as written
        self.assertEqual((self.clips["kept"]["track"], self.clips["kept"]["area"]), (written["track"], written["area"]))

    def test_image_sequence(self):
        # Given an image sequence from 3 seconds whose track request names its own crop, keyframed at clip time 0.4
        sequence = self.result["storyline"][1]["track"]

        # Then it is followed in the directory at the rate its entry reports, as --fps, from the frame its keyframe shows
        self.assertEqual(sequence["time"], 0.4)
        self.assertIn(["timeline", "<document>", "--at", "3.4", "--json"], Replay.log)
        self.assertIn(
            ["track", "/media/frames", "--fps", "25", "--at", "0.4", "--area", "[124, 202, 128, 88]", "--to", "2"],
            Replay.log
        )

    def test_probe_without_requests(self):
        # Then frames is asked only for reports, about the document with a value in the place of each request
        self.assertEqual(self.commands("evaluate") + self.commands("render") + self.commands("resolve"), [])
        probe = tool.probe_document(fixture("video.json"))
        clips = {clip["id"]: clip for clip in probe["storyline"][0]["connected"]}
        self.assertEqual(["track" in clip for clip in clips.values()], [False, False, False, False, True])
        self.assertEqual(clips["kept"]["area"], tool.PLACEHOLDER)


class Keyframed(Case):
    """`fixtures/keyframed.json`: a shot after a half second solid, from media second 0.2 at half speed, so its clock
    is `origin 0.1, speed 0.5`, with a box and a corner pin whose keyframes write their targets."""

    def setUp(self):
        super().setUp()
        self.result = self.run_document(fixture("keyframed.json"), fixture("keyframed.calls.json"))
        self.clips = {clip["id"]: clip for clip in self.result["storyline"][1]["connected"]}

    def test_keyframed(self):
        # Given track requests that name keyframed keys as their targets
        # When the tool runs
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


class Targets(Case):
    """`fixtures/targets.json`: a 640 by 360 shot conformed to a 1280 by 720 sequence, so its media pixels are half the
    output's, with requests whose targets are clips in output pixels (a rect, the same rect turned by 20 degrees, a
    rect on a corner pin), a rect that names itself, a half size media clip whose target is its ellipse mask, an
    adjustment clip without a box, and a compound clip whose nested storyline clip from media second 0.5 holds a rect
    that names itself, from nested time 0.4, so at its instant -0.1 on the nested clock."""

    def setUp(self):
        super().setUp()
        self.document = fixture("targets.json")
        self.calls = fixture("targets.calls.json")
        self.result = self.run_document(copy.deepcopy(self.document), self.calls)
        self.clips = {clip["id"]: clip for clip in self.result["storyline"][0]["connected"]}

    def followed(self, media_time):
        """The --quad or --area value of each track run from the frame at a media time, from the log."""
        tracks = [arguments for arguments in self.commands("track") if arguments[arguments.index("--at") + 1] == media_time]
        return [json.loads(arguments[arguments.index("--to") - 1]) for arguments in tracks]

    def test_targets(self):
        # Given requests whose targets are clips and a mask, in the document and in a compound clip
        # When the tool runs
        # Then every request is the track data frames printed, and nothing else of the document changes
        self.assertEqual(self.result, fixture("targets.expected.json"))

    def test_clip_in_output_pixels(self):
        # Given a rect parented to the shot whose target is a rect written in output pixels over the same place
        # Then the target is the rect's quad carried into the shot's media pixels, followed from the frame at 0.4
        self.assertIn(
            ["track", "/media/moving.mp4", "--at", "0.4", "--quad", "[[160, 194.5], [296, 194.5], [296, 290.5], [160, 290.5]]", "--to", "0"],
            Replay.log
        )
        self.assertNotIn("track", self.clips["outline"])
        self.assertEqual(self.clips["cover"]["track"]["time"], 0.4)

    def test_turned_clip(self):
        # Given a title whose target is a rect turned by 20 degrees about its centre
        quad = self.followed("1")[0]

        # Then its quadrilateral is followed, the rect's corners turned about the centre of its area in media pixels
        centre = (278, 233)
        for point, corner in zip(quad, [(210, 185), (346, 185), (346, 281), (210, 281)]):
            x, y = corner[0] - centre[0], corner[1] - centre[1]
            self.assertAlmostEqual(point[0], centre[0] + x * 0.9396926 - y * 0.3420201, places=4)
            self.assertAlmostEqual(point[1], centre[1] + x * 0.3420201 + y * 0.9396926, places=4)

    def test_corner_pinned_clip(self):
        # Given a rect whose target is a rect placed by its corner pin in output pixels
        # Then the corner pin is followed as the quadrilateral it covers in media pixels
        self.assertEqual(self.followed("1.2"), [[[220, 180], [360, 190], [355, 280], [225, 275]]] * 2)

    def test_itself(self):
        # Given a rect whose target names itself
        # Then what it covers is followed, its own area in the shot's media pixels
        quads = [json.loads(arguments[5]) for arguments in self.commands("track") if arguments[4] == "--quad"]
        self.assertIn([[160, 194], [296, 194], [296, 290], [160, 290]], quads)

    def test_mask(self):
        # Given a media clip tracked in its own media whose target is its ellipse mask, shown at half size
        # Then the rectangle that bounds the mask is followed in its media pixels, from the frame its instant shows
        self.assertIn(
            ["track", "/media/moving.mp4", "--at", "0", "--area", "[130, 170, 160, 130]", "--to", "0.4"],
            Replay.log
        )

    def test_nested(self):
        # Given a rect inside a compound clip whose instant on the nested clock is -0.1
        nested = self.result["clips"][0]["media"]["storyline"][0]["connected"][0]

        # Then it is read from the nested sequence's report on its own clock and its track data is written in place
        self.assertIn(["timeline", "<document>", "--nested", "clips[0]#inner", "--json"], Replay.log)
        self.assertIn(["timeline", "<document>", "--nested", "clips[0]#inner", "--at", "-0.1", "--json"], Replay.log)
        self.assertIn(
            ["track", "/media/moving.mp4", "--at", "0.4", "--quad", "[[124, 202], [252, 202], [252, 290], [124, 290]]", "--to", "0.48"],
            Replay.log
        )
        self.assertEqual(nested["track"]["time"], 0.4)

    def test_unknown_clip(self):
        # Given a clip target whose id no clip has, and one inside the compound clip that names a clip outside it
        document = copy.deepcopy(self.document)
        document["storyline"][0]["connected"][1]["track"]["target"] = {"clip": "nobody"}
        inside = copy.deepcopy(self.document)
        inside["clips"][0]["media"]["storyline"][0]["connected"][0]["track"]["target"] = {"clip": "outline"}

        # Then each stops, naming the id
        self.assertEqual(
            self.stop(document, self.calls),
            'storyline[0]#shot.connected[1]#cover: track.target: no clip of the sequence has the id "nobody"'
        )
        self.assertEqual(
            self.stop(inside, self.calls),
            'clips[0]#inner.media.storyline[0]#innerShot.connected[0]#innerBox: track.target: no clip of the sequence has the id "outline"'
        )

    def test_clip_without_box(self):
        # Given a clip target naming an adjustment clip
        document = copy.deepcopy(self.document)
        document["storyline"][0]["connected"][1]["track"]["target"] = {"clip": "wash"}

        # Then it stops, since an adjustment clip has no box
        self.assertEqual(
            self.stop(document, self.calls),
            "storyline[0]#shot.connected[1]#cover: track.target: storyline[0]#shot.connected[8]#wash has no box to follow"
        )


class Homography(unittest.TestCase):
    def test_projective_map(self):
        # Given a quadrilateral and a rectangle
        quad = [[440, 360], [720, 380], [710, 560], [450, 550]]
        rectangle = [[0, 0], [272, 0], [272, 192], [0, 192]]

        # When the map from the quadrilateral to the rectangle is found
        sut = tool.homography(quad, rectangle)

        # Then it takes each corner to its counterpart, and the quadrilateral's centre inside the rectangle
        for point, corner in zip(quad, rectangle):
            self.assertEqual([round(value, 6) for value in tool.projected(sut, point)], corner)
        centre = tool.projected(sut, [580, 462.5])
        self.assertTrue(0 < centre[0] < 272 and 0 < centre[1] < 192)

    def test_degenerate(self):
        # Given a quadrilateral with three corners on one line
        quad = [[0, 0], [10, 0], [20, 0], [0, 10]]

        # Then no map is found
        self.assertIsNone(tool.homography(quad, [[0, 0], [1, 0], [1, 1], [0, 1]]))

    def test_beyond_horizon(self):
        # Given the map of a quadrilateral in perspective, and a point on the far side of its horizon
        sut = tool.homography([[0, 0], [100, 0], [60, 50], [40, 50]], [[0, 0], [1, 0], [1, 1], [0, 1]])

        # Then the point is carried nowhere
        self.assertIsNone(tool.projected(sut, [50, 1000]))


class Places(Case):
    """Documents of `fixtures/places.json`, each with the frames commands the tool ran on it in
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

    def test_keyframe_without_number_at(self):
        # Given a track request that names a keyframed area, whose keyframe has no number at
        document = copy.deepcopy(self.documents["keyframed"])
        document["storyline"][0]["connected"][0]["keyframes"][1]["at"] = "1"

        # Then it stops, naming the keyframe
        self.assertIn("storyline[0]#shot.connected[0]: keyframes[1] needs a number at", self.stop(document, self.calls["keyframed"]))

    def test_request_and_clip_targets(self):
        # Given a target that is a frames/find-text request, a clip target with a padding and one whose id is no string
        padded = copy.deepcopy(self.documents["clip_target"])
        padded["storyline"][0]["connected"][1]["track"]["target"]["padding"] = 8
        numbered = copy.deepcopy(self.documents["clip_target"])
        numbered["storyline"][0]["connected"][1]["track"]["target"]["clip"] = 1

        # Then each stops before frames runs, the first since a request's arguments are values
        self.assertIn('track.target: a request\'s arguments are values, and this one holds a request for "frames/find-text"', self.place("text_target"))
        self.assertEqual(
            self.stop(padded),
            'storyline[0]#shot.connected[1]: track.target: unknown key "padding" in a clip target. Allowed: clip'
        )
        self.assertIn("track.target.clip: a clip target names a clip by its id, a string", self.stop(numbered))
        self.assertEqual(Replay.log, [])

    def test_unfilled_target(self):
        # Given a track request whose target key holds a frames/find-text request, statically and in a keyframe
        document = copy.deepcopy(self.documents["clip_target"])
        clip = document["storyline"][0]["connected"][1]
        clip["area"] = {"tool": "frames/find-text", "text": "Total"}
        clip["track"] = {"tool": "frames/track-motion", "target": "area"}
        keyframed = copy.deepcopy(document)
        del keyframed["storyline"][0]["connected"][1]["area"]
        keyframed["storyline"][0]["connected"][1]["keyframes"] = [
            {"at": 0, "area": [0, 0, 10, 10]}, {"at": 1, "area": {"tool": "frames/find-text", "text": "Total"}}
        ]

        # Then each stops before frames runs, naming the request that is not filled
        self.assertEqual(
            self.stop(document),
            'storyline[0]#shot.connected[1]: track: its target "area" holds a request for "frames/find-text" at area, which is not '
            'filled yet: run frames frames/find-text first, since the target is the value it finds'
        )
        self.assertIn('holds a request for "frames/find-text" at keyframes[1].area', self.stop(keyframed))
        self.assertEqual(Replay.log, [])

    def test_target_forms(self):
        # Given requests without a target, and with a target that names no key a target lies in
        document = copy.deepcopy(self.documents["bad_key"])
        clip = document["storyline"][0]["connected"][0]
        messages = []
        for track in ({"tool": "frames/track-motion"}, {"tool": "frames/track-motion", "target": "position"}):
            clip["track"] = track
            messages.append(self.stop(copy.deepcopy(document)))

        # Then each stops, naming what is wrong
        self.assertIn("a frames/track-motion request names its target", messages[0])
        self.assertIn('track.target: "position" is none of the clip\'s own keys a target lies in: area, cornerPin, crop, mask', messages[1])

    def test_unknown_key(self):
        # Given requests with a key they do not take, one of them a media time
        document = copy.deepcopy(self.documents["bad_key"])
        document["storyline"][0]["connected"][0]["track"] = {"tool": "frames/track-motion", "target": "area", "time": 0.4}

        # Then each stops before frames runs, naming the key
        self.assertIn('unknown key "padding" in a frames/track-motion request. Allowed: target, tool', self.place("bad_key"))
        self.assertEqual(
            self.stop(document),
            'storyline[0]#shot.connected[0]: track: unknown key "time" in a frames/track-motion request. Allowed: target, tool'
        )
        self.assertEqual(Replay.log, [])


class Arguments(Case):
    def test_no_request(self):
        # Given a document whose track is a boolean, and one whose only request is for another tool
        document = {"kind": "sequence", "storyline": [{"kind": "media", "media": "/media/moving.mp4", "track": True, "connected": [
            {"kind": "rect", "area": {"tool": "frames/find-text", "text": "Total"}, "track": {"tool": "other", "target": "area"}}
        ]}]}

        # When the tool runs
        result = self.run_document(copy.deepcopy(document), [])

        # Then it is printed as it is, and frames is not run, so frames stops on what is not its own
        self.assertEqual(result, document)
        self.assertEqual(Replay.log, [])

    def test_misplaced(self):
        # Given a frames/track-motion request as a clip's area
        document = {"kind": "sequence", "storyline": [{"kind": "media", "media": "/media/moving.mp4", "connected": [
            {"kind": "rect", "area": {"tool": "frames/track-motion", "target": [0, 0, 10, 10]}}
        ]}]}

        # Then it stops, since it stands as a clip's track
        self.assertIn("storyline[0].connected[0]: area: a frames/track-motion request stands as a clip's track", self.stop(document))

    def test_relative_path(self):
        # Then a relative document path stops
        with self.assertRaises(tool.Stop) as raised:
            tool.parse(["edit.json"])
        self.assertIn("is not an absolute path", str(raised.exception))

    def test_global_options(self):
        # Then the global options of frames are passed on
        self.assertEqual(tool.parse(["--tracker", "planar", "/abs/edit.json"]), (["--tracker", "planar"], "/abs/edit.json"))


class Failure(unittest.TestCase):
    def test_without_frames(self):
        # Given a document with a request, and no frames executable given
        path = os.path.join(tempfile.mkdtemp(prefix="track-motion-test-"), "document.json")
        self.addCleanup(shutil.rmtree, os.path.dirname(path), True)
        with open(path, "w", encoding="utf-8") as file:
            json.dump(fixture("video.json"), file)

        # When the tool runs
        with self.assertRaises(tool.Stop) as raised:
            tool.run([path], None)

        # Then it stops, since only frames gives the executable it runs
        self.assertEqual(str(raised.exception), "FRAMES_EXECUTABLE is not set: the tool is run by frames, as frames frames/track-motion")

    def test_failed_command(self):
        # Given a frames that fails on every command, run with a global option
        directory = tempfile.mkdtemp(prefix="track-motion-test-")
        self.addCleanup(shutil.rmtree, directory, True)
        executable = os.path.join(directory, "frames")
        with open(executable, "w", encoding="utf-8") as file:
            file.write("#!/bin/sh\necho 'frames: no theme named \"brand/dark\"' >&2\nexit 1\n")
        os.chmod(executable, stat.S_IRWXU)
        sut = tool.Frames(executable, ["--theme", "brand/dark"])

        # When it runs a report
        with self.assertRaises(tool.Stop) as raised:
            sut.report(["timeline", "/abs/edit json.json", "--json"])

        # Then the stop shows the command line it ran, with its global options, and what frames printed
        self.assertEqual(
            str(raised.exception),
            f"{shlex.quote(executable)} --theme brand/dark timeline '/abs/edit json.json' --json failed: frames: no theme named \"brand/dark\""
        )


if __name__ == "__main__":
    unittest.main()
