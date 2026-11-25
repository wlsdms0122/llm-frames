//
//  CommandTable.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// The commands frames has, by name. A command is added as its own type and one line here. A command word with a `/`
// names a pack's tool, so no name here has one.
enum CommandTable {
    static let commands: [any Command] = [
        RenderCommand(),
        StillCommand(),
        ResolveCommand(),
        TimelineCommand(),
        EvaluateCommand(),
        LocateCommand(),
        ProbeCommand(),
        LoudnessCommand(),
        OCRCommand(),
        TrackCommand(),
        ExtractCommand(),
        SheetCommand(),
        TranscodeCommand(),
        PresetsCommand(),
        PacksCommand(),
        ThemeCommand()
    ]
}
