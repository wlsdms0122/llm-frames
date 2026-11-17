//
//  CommandUsage.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// What frames prints when it is run without a command: the command line grammar of FRAMES-23.
enum CommandUsage {
    static let text = """
        frames [--theme <pack/name | /abs/theme.json>] [--decoder <name>] [--renderer <name>] [--mixer <name>] \
        [--encoder <name>] [--ocr <name>] [--shaper <name>] [--tracker <name>] <command> ...

        render    <document.json> -o <out.mov | out.png> [--at <t>] [--deliver <out.mp4>] [--args <args.json>]
        still     <document.json> --at <t>[,<t>...] -o <out.png> [--args <args.json>]
        resolve   <document.json> -o <resolved.json> [--args <args.json>]
        timeline  <document.json> [--args <args.json>] [--json]
        evaluate  <document.json> --at <t> [--args <args.json>]
        locate    <document.json> --at <t> --point <x,y> [--args <args.json>]
        probe     <media> [--json]
        ocr       <image | video> [--at <t> | --from <t> --to <t> --step <s>] [--json]
        track     <video> --at <t> --area <area> [--to <t>]
        extract   <video | document.json> <outdir> [--from <t>] [--to <t>] [--step 1]
        sheet     <video | document.json> -o <out.png> [--from <t>] [--to <t>] [--step 1] [--cols 6]
        transcode <in> -o <out> [--quality high|medium|low] [--max <px>] [--codec h264|hevc]
        presets   [<kind>] [<name>]
        packs     [<pack>]
        theme

        """
}
