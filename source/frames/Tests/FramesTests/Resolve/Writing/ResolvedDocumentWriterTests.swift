//
//  ResolvedDocumentWriterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("ResolvedDocumentWriter Tests")
struct ResolvedDocumentWriterTests {
    // MARK: - Property
    private let sut = ResolvedDocumentWriter(hashes: FileHashTable([
        "/abs/run.mp4": "9f2c41d07b3e",
        "/abs/bgm.m4a": "c07d9a1e44f2",
        "/abs/page.png": "5d17e0a9b2c4",
        "/System/Apple SD Gothic Neo.ttc": "41aa0c9e5d17"
    ]))

    // A sequence shaped like the example of the resolved document: a cropped, filtered storyline clip at speed 2, a
    // title that pops in, and looping music that fades out.
    private let sequence = #"""
        { "kind": "sequence", "format": { "size": [1080, 1920], "inset": [40, 40, 500, 40] },
          "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "filter": "grade",
                           "keyframes": [ { "at": 2, "crop": [0, 0, 1080, 1920] }, { "at": 8, "crop": [45, 97, 990, 1760] } ] } ],
          "clips": [ { "title": "Hi", "style": "label", "at": [0, 3], "animation": "pop", "position": [75.4, 1709.8] },
                     { "media": "/abs/bgm.m4a", "at": 0, "loop": true,
                       "keyframes": [ { "at": 0, "volume": 0.3 }, { "at": 2, "volume": 0.3 }, { "at": 3, "volume": 0 } ] } ] }
        """#
    private let image = #"""
        { "kind": "image", "source": "/abs/page.png",
          "ops": [ { "crop": [100, 100, 400, 200] }, { "shape": "box", "area": [150, 150, 100, 50] } ] }
        """#

    private let resolvedSequence = #"""
        {
          "kind": "sequence",
          "resolved": "1.0.0",
          "format": {
            "size": [1080, 1920],
            "fps": 30,
            "duration": 3,
            "background": "#FFFFFFFF",
            "content": [40, 40, 1000, 1380],
            "conform": "fit"
          },
          "storyline": [
            {
              "place": "storyline[0]",
              "id": null,
              "media": {
                "file": "/abs/run.mp4",
                "sha256": "9f2c41d07b3e"
              },
              "in": 2,
              "out": 8,
              "speed": 2,
              "start": 0,
              "end": 3,
              "crop": [
                {
                  "at": 0,
                  "value": [-155.6521739130435, 0, 1391.304347826087, 1920],
                  "ease": "linear"
                },
                {
                  "at": 3,
                  "value": [-97.68115942028987, 97, 1275.3623188405797, 1760],
                  "ease": "linear"
                }
              ],
              "track": null,
              "filter": [
                {
                  "op": "saturation",
                  "amount": 1.25
                },
                {
                  "op": "blur",
                  "radius": 3.582089552238806
                }
              ],
              "transition": null
            }
          ],
          "clips": [
            {
              "place": "clips[0]",
              "id": null,
              "title": {
                "size": [60.8955223880597, 54.62686567164179],
                "lines": 1,
                "background": {
                  "color": "#ED2929FF",
                  "padding": [14.328358208955224, 7.164179104477612],
                  "radius": 10.746268656716419
                },
                "stroke": null,
                "runs": [
                  {
                    "file": "/System/Apple SD Gothic Neo.ttc",
                    "sha256": "41aa0c9e5d17",
                    "face": "Apple SD Gothic Neo-bold",
                    "size": 32.23880597014926,
                    "color": "#FFFFFFFF",
                    "glyphs": [
                      [72, 14.328358208955224, 36.985074626865675],
                      [105, 30.44776119402985, 36.985074626865675]
                    ]
                  }
                ]
              },
              "start": 0,
              "end": 3,
              "lane": 1,
              "parent": null,
              "area": null,
              "position": [
                {
                  "at": 0,
                  "value": [75.4, 1709.8],
                  "ease": "linear"
                }
              ],
              "crop": null,
              "track": null,
              "label": null,
              "opacity": [
                {
                  "at": 0,
                  "value": 1,
                  "ease": "linear"
                }
              ],
              "scale": [
                {
                  "at": 0,
                  "value": 1,
                  "ease": "linear"
                }
              ],
              "rotation": [
                {
                  "at": 0,
                  "value": 0,
                  "ease": "linear"
                }
              ],
              "blend": "normal",
              "animation": {
                "entrance": {
                  "seconds": 0.25,
                  "ease": "linear",
                  "revealFrom": "left",
                  "keys": []
                },
                "loop": null,
                "exit": null
              }
            }
          ],
          "audio": [
            {
              "place": "storyline[0]",
              "media": {
                "file": "/abs/run.mp4",
                "sha256": "9f2c41d07b3e"
              },
              "nested": [],
              "in": 2,
              "out": 8,
              "speed": 2,
              "loop": false,
              "start": 0,
              "end": 3,
              "audible": [0, 3],
              "volume": [
                {
                  "at": 0,
                  "value": 1,
                  "ease": "linear"
                }
              ],
              "fadeIn": null,
              "fadeOut": null,
              "incoming": null,
              "outgoing": null
            },
            {
              "place": "clips[1]",
              "media": {
                "file": "/abs/bgm.m4a",
                "sha256": "c07d9a1e44f2"
              },
              "nested": [],
              "in": 0,
              "out": 20,
              "speed": 1,
              "loop": true,
              "start": 0,
              "end": 3,
              "audible": [0, 3],
              "volume": [
                {
                  "at": 0,
                  "value": 0.3,
                  "ease": "linear"
                },
                {
                  "at": 2,
                  "value": 0.3,
                  "ease": "linear"
                },
                {
                  "at": 3,
                  "value": 0,
                  "ease": "linear"
                }
              ],
              "fadeIn": null,
              "fadeOut": null,
              "incoming": null,
              "outgoing": null
            }
          ]
        }

        """#
    private let resolvedImage = #"""
        {
          "kind": "image",
          "resolved": "1.0.0",
          "size": [400, 200],
          "steps": [
            {
              "draw": "picture",
              "picture": {
                "file": "/abs/page.png",
                "sha256": "5d17e0a9b2c4",
                "time": 0
              },
              "crop": [100, 100, 400, 200],
              "frame": [0, 0, 400, 200],
              "clip": [0, 0, 400, 200]
            },
            {
              "draw": "box",
              "area": [50, 50, 100, 50],
              "width": 2.6533996683250414,
              "radius": 5.970149253731343,
              "color": "#ED2929FF",
              "clip": [0, 0, 400, 200]
            }
          ]
        }

        """#

    // MARK: - Initializer
    // MARK: - Test
    @Test("a sequence resolves to the same text as its golden resolved document")
    func writesGoldenSequence() throws {
        // Given
        let plan = try Fixture.documentPlanner.plan(Fixture.json(sequence))

        // When
        let text = try sut.write(plan)

        // Then
        #expect(text == resolvedSequence)
    }

    @Test("an image resolves to the same text as its golden resolved document")
    func writesGoldenImage() throws {
        // Given
        let plan = try Fixture.documentPlanner.plan(Fixture.json(image))

        // When
        let text = try sut.write(plan)

        // Then
        #expect(text == resolvedImage)
    }

    @Test("resolving the same document twice gives the same bytes", arguments: [0, 1])
    func resolvesDeterministically(index: Int) throws {
        // Given
        let document = try Fixture.json([sequence, image][index])
        let writer = ResolvedDocumentWriter(hashes: FileHashTable())

        // When
        let first = try writer.write(Fixture.documentPlanner.plan(document))
        let second = try ResolvedDocumentWriter(hashes: FileHashTable()).write(planner().plan(document))

        // Then
        #expect(Data(first.utf8) == Data(second.utf8))
    }

    @Test("a resolved document reads back to the value it was written from")
    func readsBack() throws {
        // Given
        let value = try sut.document(Fixture.documentPlanner.plan(Fixture.json(sequence)))

        // When
        let read = try JSONReader().read(JSONWriter().write(value))

        // Then
        #expect(read == value)
    }

    // MARK: - Private
    // A planner of its own, so nothing one resolve leaves behind reaches the other.
    private func planner() -> DocumentPlanner {
        DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Fixture.presets,
            ocr: Fixture.ocr,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            library: Fixture.library
        )
    }
}
