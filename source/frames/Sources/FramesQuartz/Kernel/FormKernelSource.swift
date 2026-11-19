//
//  FormKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/20/26.
//

// The Metal functions that take a colour between the two forms of the working values (FRAMES-26): the extended sRGB
// transfer on each channel, the sign kept and the same curve above 1. A kernel's samples are in the form of the
// context it is computed in, which its `linear` argument names, 1 for the linear form and 0 for the encoded one, and
// a formula with a home on one form takes its colours there and its result back. Every other kernel source is joined
// after this one.
enum FormKernelSource {
    static let text = """
        static inline float3 formEncode(float3 light) {
            float3 magnitude = abs(light);
            return select(sign(light) * (1.055 * pow(magnitude, 1.0 / 2.4) - 0.055), 12.92 * light, magnitude <= 0.0031308);
        }

        static inline float3 formDecode(float3 value) {
            float3 magnitude = abs(value);
            return select(sign(value) * pow((magnitude + 0.055) / 1.055, 2.4), value / 12.92, magnitude <= 0.04045);
        }

        static inline float3 formToEncoded(float3 color, float linear) {
            return linear > 0.5 ? formEncode(color) : color;
        }

        static inline float3 formFromEncoded(float3 color, float linear) {
            return linear > 0.5 ? formDecode(color) : color;
        }

        static inline float3 formToLinear(float3 color, float linear) {
            return linear > 0.5 ? color : formDecode(color);
        }

        static inline float3 formFromLinear(float3 color, float linear) {
            return linear > 0.5 ? color : formEncode(color);
        }

        // The Rec. 709 luma of an unpremultiplied colour in the form `linear` names, taken on the encoded form.
        static inline float formLuma(float3 color, float linear) {
            return dot(formToEncoded(color, linear), float3(0.2126, 0.7152, 0.0722));
        }
        """
}
