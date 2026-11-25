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
    // title in a style its theme adds that pops in, a still with a border in the centre, and looping music panned a
    // little left that fades out.
    private let sequence = #"""
        { "kind": "sequence", "format": { "size": [1080, 1920] },
          "theme": { "styles": { "label": { "size": 36, "weight": "bold", "color": "#FFFFFF",
                                            "background": { "color": "#ED2929", "padding": [8, 16], "radius": 12 }, "lines": 1 } } },
          "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "filter": "mine/grade",
                           "anchor": "top-left", "position": [0, 0], "blend": "screen", "border": true,
                           "keyframes": [ { "at": 2, "crop": [0, 0, 1080, 1920], "scale": 1 },
                                          { "at": 8, "crop": [45, 97, 990, 1760], "scale": 0.5 } ] } ],
          "clips": [ { "kind": "title", "text": "Hi", "style": "label", "at": [0, 3], "animation": "frames/pop", "position": [75.4, 1709.8] },
                     { "kind": "media", "media": "/abs/page.png", "at": [0, 3], "width": 200, "border": true },
                     { "kind": "audio", "media": "/abs/bgm.m4a", "at": 0, "loop": true, "pan": -0.2,
                       "keyframes": [ { "at": 0, "volume": 0.3 }, { "at": 2, "volume": 0.3 }, { "at": 3, "volume": 0 } ] } ] }
        """#
    private let resolvedSequence = #"""
        {
          "kind": "sequence",
          "resolved": "0.1.0",
          "format": {
            "size": [1080, 1920],
            "fps": 30,
            "duration": 3,
            "background": "color(srgb 0 0 0 / 1)",
            "conform": "fit",
            "colorSpace": "srgb",
            "peak": null,
            "compositing": "encoded",
            "motionBlur": {
              "shutterAngle": 180,
              "shutterPhase": 0,
              "samplesPerFrame": 16
            }
          },
          "storyline": [
            {
              "place": "storyline[0]",
              "id": null,
              "kind": "media",
              "media": {
                "kind": "file",
                "file": "/abs/run.mp4",
                "sha256": "9f2c41d07b3e",
                "frames": null
              },
              "color": null,
              "colorSpace": null,
              "toneMap": true,
              "in": 2,
              "out": 8,
              "speed": 2,
              "timeRemap": null,
              "start": 0,
              "end": 3,
              "size": [1080, 1920],
              "position": [
                {
                  "at": 0,
                  "value": [0, 0],
                  "ease": "linear"
                }
              ],
              "anchor": [0, 0],
              "cornerPin": null,
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
              "mask": null,
              "trackMatte": null,
              "track": null,
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
                  "value": [1, 1],
                  "ease": "linear"
                },
                {
                  "at": 3,
                  "value": [0.5, 0.5],
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
              "blend": "screen",
              "motionBlur": false,
              "filter": [
                {
                  "ops": [
                    {
                      "kind": "saturation",
                      "amount": [
                        {
                          "at": 0,
                          "value": 1.25,
                          "ease": "linear"
                        }
                      ]
                    },
                    {
                      "kind": "blur",
                      "radius": [
                        {
                          "at": 0,
                          "value": 2.25,
                          "ease": "linear"
                        }
                      ]
                    }
                  ],
                  "mix": [
                    {
                      "at": 0,
                      "value": 1,
                      "ease": "linear"
                    }
                  ]
                }
              ],
              "radius": null,
              "border": {
                "width": [
                  {
                    "at": 0,
                    "value": 2.25,
                    "ease": "linear"
                  }
                ],
                "color": [
                  {
                    "at": 0,
                    "value": "color(srgb 1 1 1 / 1)",
                    "ease": "linear"
                  }
                ],
                "align": "inside"
              },
              "shadow": null,
              "transition": null
            }
          ],
          "clips": [
            {
              "place": "clips[0]",
              "id": null,
              "kind": "title",
              "title": {
                "size": [38.25, 29.25],
                "textBox": [9, 4.5, 20.25, 20.25],
                "width": null,
                "background": {
                  "color": [
                    {
                      "at": 0,
                      "value": "color(srgb 0.9294117647058824 0.1607843137254902 0.1607843137254902 / 1)",
                      "ease": "linear"
                    }
                  ],
                  "padding": [
                    {
                      "at": 0,
                      "value": [4.5, 9],
                      "ease": "linear"
                    }
                  ],
                  "radius": [
                    {
                      "at": 0,
                      "value": [6.75, 6.75, 6.75, 6.75],
                      "ease": "linear"
                    }
                  ]
                },
                "writingMode": "horizontal-tb",
                "direction": "ltr",
                "align": "left",
                "lineHeight": [
                  {
                    "at": 0,
                    "value": 25.3125,
                    "ease": "linear"
                  }
                ],
                "text": "Hi",
                "words": [
                  [0, 2]
                ],
                "lines": [
                  {
                    "width": 20.25,
                    "baseline": 20.7,
                    "ascent": 16.2,
                    "descent": 4.05,
                    "range": [0, 2],
                    "clusters": [
                      [0, 0, 1, 0, 1, 10.125, 0, ""],
                      [0, 1, 1, 1, 2, 10.125, 0, ""]
                    ],
                    "hanging": []
                  }
                ],
                "units": null,
                "runs": [
                  {
                    "source": 0,
                    "file": "/System/Apple SD Gothic Neo.ttc",
                    "sha256": "41aa0c9e5d17",
                    "face": "Apple SD Gothic Neo-bold",
                    "size": 20.25,
                    "color": [
                      {
                        "at": 0,
                        "value": "color(srgb 1 1 1 / 1)",
                        "ease": "linear"
                      }
                    ],
                    "stroke": null,
                    "baselineShift": [
                      {
                        "at": 0,
                        "value": 0,
                        "ease": "linear"
                      }
                    ],
                    "sideways": false,
                    "horizontalScale": 1,
                    "staticTracking": 0,
                    "tracking": null,
                    "highlight": null,
                    "underline": null,
                    "glyphs": [
                      [72, 9, 20.7, 0, 0],
                      [105, 19.125, 20.7, 0, 0]
                    ]
                  }
                ]
              },
              "start": 0,
              "end": 3,
              "lane": 1,
              "storyline": null,
              "parent": null,
              "size": [38.25, 29.25],
              "position": [
                {
                  "at": 0,
                  "value": [75.4, 1709.8],
                  "ease": "linear"
                }
              ],
              "anchor": [19.125, 14.625],
              "cornerPin": null,
              "crop": null,
              "mask": null,
              "trackMatte": null,
              "track": null,
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
                  "value": [1, 1],
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
              "motionBlur": false,
              "animation": {
                "entrance": {
                  "seconds": 0.25,
                  "ease": "linear",
                  "revealFrom": "left",
                  "keys": []
                },
                "loop": null,
                "exit": null,
                "by": null,
                "stagger": null,
                "order": null
              }
            },
            {
              "place": "clips[1]",
              "id": null,
              "kind": "media",
              "media": {
                "kind": "file",
                "file": "/abs/page.png",
                "sha256": "5d17e0a9b2c4",
                "frames": null
              },
              "filter": null,
              "conform": "fit",
              "colorSpace": null,
              "toneMap": true,
              "radius": null,
              "border": {
                "width": [
                  {
                    "at": 0,
                    "value": 2.25,
                    "ease": "linear"
                  }
                ],
                "color": [
                  {
                    "at": 0,
                    "value": "color(srgb 1 1 1 / 1)",
                    "ease": "linear"
                  }
                ],
                "align": "inside"
              },
              "shadow": null,
              "start": 0,
              "end": 3,
              "lane": 1,
              "storyline": null,
              "parent": null,
              "size": [200, 160],
              "position": [
                {
                  "at": 0,
                  "value": [540, 960],
                  "ease": "linear"
                }
              ],
              "anchor": [100, 80],
              "cornerPin": null,
              "crop": [
                {
                  "at": 0,
                  "value": [0, 0, 1000, 800],
                  "ease": "linear"
                }
              ],
              "mask": null,
              "trackMatte": null,
              "track": null,
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
                  "value": [1, 1],
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
              "motionBlur": false,
              "animation": {
                "entrance": null,
                "loop": null,
                "exit": null,
                "by": null,
                "stagger": null,
                "order": null
              }
            }
          ],
          "audio": [
            {
              "place": "storyline[0]",
              "media": {
                "kind": "file",
                "file": "/abs/run.mp4",
                "sha256": "9f2c41d07b3e",
                "frames": null
              },
              "nested": null,
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
              "pan": [
                {
                  "at": 0,
                  "value": 0,
                  "ease": "linear"
                }
              ],
              "fadeIn": null,
              "fadeOut": null,
              "incoming": null,
              "outgoing": null,
              "audioFilter": null
            },
            {
              "place": "clips[2]",
              "media": {
                "kind": "file",
                "file": "/abs/bgm.m4a",
                "sha256": "c07d9a1e44f2",
                "frames": null
              },
              "nested": null,
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
              "pan": [
                {
                  "at": 0,
                  "value": -0.2,
                  "ease": "linear"
                }
              ],
              "fadeIn": null,
              "fadeOut": null,
              "incoming": null,
              "outgoing": null,
              "audioFilter": null
            }
          ],
          "audioFilter": null
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
            shaper: Fixture.shaper,
            library: Fixture.library
        )
    }
}
