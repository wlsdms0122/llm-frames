//
//  CommandTable.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// The commands frames has, by name. A command is added as its own type and one line here, and a name not here is an
// extension's.
enum CommandTable {
    static let commands: [any Command] = [
        RenderCommand(),
        StillCommand(),
        ResolveCommand(),
        TimelineCommand(),
        EvaluateCommand(),
        LocateCommand(),
        ProbeCommand(),
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
