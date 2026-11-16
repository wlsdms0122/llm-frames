//
//  InjectedFailure.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

// What `FailingRenderer` throws in place of the frame it is made to fail.
enum InjectedFailure: Error, Equatable {
    case frame(Int)
}
