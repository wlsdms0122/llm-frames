//
//  Mixer.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Mixes the sound of a sequence from its mix plan.
package protocol Mixer: Sendable {
    // Refuses a plan holding anything the mixer cannot mix, naming the first such thing and its place in the plan.
    func check(_ plan: MixPlan) throws

    // 48 kHz stereo, the plan's `length` samples per channel from sequence time 0.
    func mix(_ plan: MixPlan) throws -> SoundBuffer
}
