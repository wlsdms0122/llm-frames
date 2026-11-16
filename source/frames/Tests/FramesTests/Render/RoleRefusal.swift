//
//  RoleRefusal.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

// What a recording role throws from its check when it is made to refuse.
enum RoleRefusal: Error, Equatable, CaseIterable {
    case decoder
    case renderer
    case mixer
    case encoder
}
