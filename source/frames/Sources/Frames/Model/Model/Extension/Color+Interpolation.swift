//
//  Color+Interpolation.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// How colours are mixed by a weight, on the encoded form: a keyframed colour straight, a gradient's stops
// premultiplied.
extension Color {
    // MARK: - Property
    // Red, green and blue of the encoded form premultiplied by alpha, and alpha.
    var premultiplied: [Double] {
        [red * alpha, green * alpha, blue * alpha, alpha]
    }

    // MARK: - Initializer
    // The colour of premultiplied red, green, blue and alpha; transparent where alpha is 0.
    init(premultiplied channels: [Double]) {
        let alpha = channels[3]
        guard alpha > 0 else {
            self = .transparent
            return
        }

        self.init(red: channels[0] / alpha, green: channels[1] / alpha, blue: channels[2] / alpha, alpha: alpha)
    }

    // MARK: - Public
    // A keyframed colour between two keyframes, straight. An ease that overshoots is held where the value is sampled:
    // alpha to 0 to 1, and each of red, green and blue to min(0, a, b) to max(1, a, b), with a and b that channel's
    // values at the span's two keyframes (FRAMES-4).
    static func interpolate(
        from start: Color,
        to end: Color,
        progress: Double
    ) -> Color {
        let mixed = { (start: Double, end: Double) in
            min(max(start + (end - start) * progress, min(0, start, end)), max(1, start, end))
        }

        return Color(
            red: mixed(start.red, end.red),
            green: mixed(start.green, end.green),
            blue: mixed(start.blue, end.blue),
            alpha: min(max(start.alpha + (end.alpha - start.alpha) * progress, 0), 1)
        )
    }

    // MARK: - Private
}
