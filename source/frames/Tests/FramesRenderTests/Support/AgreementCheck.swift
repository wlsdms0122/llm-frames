//
//  AgreementCheck.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/25/26.
//

// What a case is held to beside the agreement of its pixels.
enum AgreementCheck: Sendable {
    // The frame at `time` mixes the picture shown alone at `outgoing` and the one shown alone at `incoming`, each
    // detailed and the two different.
    case mix(outgoing: Double, incoming: Double, at: Double)
    // The edge lies at the same position in the frames of both renderers at each of the case's times.
    case edge(EdgeProbe)
}
