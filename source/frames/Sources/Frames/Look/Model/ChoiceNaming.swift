//
//  ChoiceNaming.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How an object of a choice names its form, and what an object that names none changes.
enum ChoiceNaming: Equatable, Sendable {
    // `preset` names the preset, and an object without it changes the choice below it, which it needs: a transition.
    case preset
    // As `preset`, but an off name and no value are the choice of nothing, so an object without `preset` over them
    // stands for what it writes, its `args` excepted, which name no preset's parameters: an animation, whose `"none"`
    // is the animation with no spans.
    case presetOverNone
    // `kind` names the form, an op's or a band's name, or `preset` for a preset entry whose `preset` names its preset.
    // A preset entry without `preset` changes the preset entry below it, and an object without `kind` is a keyframe's,
    // which writes leaves of the form below: a filter's and an audio filter's entries, the ops of a resolved entry and
    // an `eq`'s bands.
    case kind
}
