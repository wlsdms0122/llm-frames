//
//  main.swift
//  FramesTool
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesCommand

exit(CommandShell(environment: .current, output: .standard).run(Array(CommandLine.arguments.dropFirst())))
