# FRAMES-18: Versions

Status: accepted

## Summary

frames is versioned major.minor.patch, and everything frames reads or writes follows that one version: documents, presets, themes, templates, packs, commands, the resolved document and machine output.

## Motivation

Packs, and the tools they carry, are made once and used by many frames, and resolved documents are kept to make results again. One version with semantic rules tells each of them what still holds.

## Rules

- frames is versioned `major.minor.patch` (semantic versioning), and this specification, at 0.1.0, is what the version is about: document keys and values, presets, themes, templates, packs, commands, the values of the base theme and of the presets frames ships, and what frames writes for others to read: the resolved document, the display list, the mix plan and machine output. An addition (a key, an op, a preset, a form of a value, a command) raises the minor number. A removal, a renamed key, or a changed value of the base theme or a preset raises the major number. A fix that brings an implementation to this specification raises the patch number. A name never changes its meaning within a major version: a new meaning takes a new name.
- The resolved document, the display list, the mix plan and each machine output object carry the version of the frames that wrote them ([FRAMES-19](../FRAMES-19/SPEC.md) and [FRAMES-23](../FRAMES-23/SPEC.md)). A new key in one is an addition, and a removed or changed one a major change, so a resolved document stays readable by every later frames of its major version.
- A pack names the versions of frames it is written for as a range in `engine` in its `pack.json`, where `"^1.2"` is 1.2.0 or later before 2.0.0. The range is written `^major`, `^major.minor` or `^major.minor.patch`, its missing parts 0, and any other spelling stops. Outside it, the pack stops when it is used, naming both.
- A document names no version. It is resolved by the frames that reads it, and what it resolved to is kept in its resolved document ([FRAMES-19](../FRAMES-19/SPEC.md)), so a document that must be made again the same way keeps its resolved document. A pack is checked because it is made once and used by many frames.

## Interactions

A resolved document is read by [FRAMES-19](../FRAMES-19/SPEC.md). Machine output is [FRAMES-23](../FRAMES-23/SPEC.md). Packs are [FRAMES-17](../FRAMES-17/SPEC.md).

## Alternatives considered

Separate schema numbers for the resolved document and machine output: a minor upgrade could refuse every kept resolved document. A version named in every document: a document is resolved by the frames that reads it, and its resolved document keeps the result.

## Notes
