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
    private let sut = ResolvedDocumentWriter()
    private let hashes = FileHashTable([
        "/abs/run.mp4": "9f2c41d07b3e",
        "/abs/bgm.m4a": "c07d9a1e44f2",
        "/abs/page.png": "5d17e0a9b2c4",
        "/System/Apple SD Gothic Neo.ttc": "41aa0c9e5d17"
    ])

    // A sequence shaped like the example of the resolved document: a cropped, filtered storyline clip at speed 2, a
    // title that pops in, a still with a border in the centre, and looping music that fades out.
    private let sequence = #"""
        { "kind": "sequence", "format": { "size": [1080, 1920] },
          "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "filter": "mine/grade",
                           "keyframes": [ { "at": 2, "crop": [0, 0, 1080, 1920] }, { "at": 8, "crop": [45, 97, 990, 1760] } ] } ],
          "clips": [ { "title": "Hi", "style": "label", "at": [0, 3], "animation": "frames/pop", "position": [75.4, 1709.8] },
                     { "media": "/abs/page.png", "at": [0, 3], "width": 200, "border": true },
                     { "media": "/abs/bgm.m4a", "at": 0, "loop": true,
                       "keyframes": [ { "at": 0, "volume": 0.3 }, { "at": 2, "volume": 0.3 }, { "at": 3, "volume": 0 } ] } ] }
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
              "solid": null,
              "in": 2,
              "out": 8,
              "speed": 2,
              "start": 0,
              "end": 3,
              "crop": [
                {
                  "at": 0,
                  "value": [0, 0, 1080, 1920],
                  "ease": "linear"
                },
                {
                  "at": 3,
                  "value": [45, 97, 990, 1760],
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
              "storyline": null,
              "parented": false,
              "area": null,
              "size": [60.8955223880597, 54.62686567164179],
              "position": [
                {
                  "at": 0,
                  "value": [44.952238805970154, 1682.486567164179],
                  "ease": "linear"
                }
              ],
              "anchor": [30.44776119402985, 27.313432835820894],
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
            },
            {
              "place": "clips[1]",
              "id": null,
              "media": {
                "file": "/abs/page.png",
                "sha256": "5d17e0a9b2c4"
              },
              "filter": [],
              "conform": "fit",
              "radius": 0,
              "border": {
                "width": 2.6865671641791047,
                "color": "#D9D9D9FF"
              },
              "shadow": null,
              "start": 0,
              "end": 3,
              "lane": 1,
              "storyline": null,
              "parented": false,
              "area": null,
              "size": [200, 160],
              "position": [
                {
                  "at": 0,
                  "value": [440, 880],
                  "ease": "linear"
                }
              ],
              "anchor": [100, 80],
              "crop": [
                {
                  "at": 0,
                  "value": [0, 0, 1000, 800],
                  "ease": "linear"
                }
              ],
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
                "entrance": null,
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
              "origin": 0,
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
              "place": "clips[2]",
              "media": {
                "file": "/abs/bgm.m4a",
                "sha256": "c07d9a1e44f2"
              },
              "nested": [],
              "in": 0,
              "origin": 0,
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

    // MARK: - Initializer
    // MARK: - Test
    @Test("a sequence resolves to the same text as its golden resolved document")
    func writesGoldenSequence() throws {
        // Given
        let plan = try Fixture.documentPlanner.plan(Fixture.json(sequence))

        // When
        let text = sut.write(try ResolvedSequence(plan: plan, hashes: hashes))

        // Then
        #expect(text == resolvedSequence)
    }

    @Test("resolving the same document twice gives the same bytes")
    func resolvesDeterministically() throws {
        // Given
        let document = try Fixture.json(sequence)

        // When
        let first = sut.write(try ResolvedSequence(plan: Fixture.documentPlanner.plan(document), hashes: FileHashTable()))
        let second = ResolvedDocumentWriter().write(try ResolvedSequence(plan: planner().plan(document), hashes: FileHashTable()))

        // Then
        #expect(Data(first.utf8) == Data(second.utf8))
    }

    @Test("a resolved document reads back to the value it was written from")
    func readsBack() throws {
        // Given
        let value = sut.document(try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(sequence)), hashes: hashes))

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
