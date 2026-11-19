//
//  Color+Channel.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

extension Color {
    // MARK: - Property
    // Red, green, blue and alpha from 0 to 1, straight, on the sRGB-encoded values of the working space.
    var channels: [Double] {
        let digits = Array(hex.dropFirst())
        return stride(from: 0, to: 8, by: 2).map { index in
            Double(Int(String(digits[index ..< index + 2]), radix: 16) ?? 0) / 255
        }
    }

    // MARK: - Initializer
    // Each channel is clamped to 0 to 1 and kept to the eight bits `#RRGGBBAA` holds.
    init(channels: [Double]) {
        let digits = channels.map { channel in
            String(format: "%02X", Int((min(max(channel, 0), 1) * 255).rounded()))
        }
        self.init(written: "#" + digits.joined())
    }

    // MARK: - Public
    // MARK: - Private
}
