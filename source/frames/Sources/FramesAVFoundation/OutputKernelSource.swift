//
//  OutputKernelSource.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

// The Metal compute functions that take a frame of working values, RGBA half floats with premultiplied alpha, to an
// SDR output's code values, as the steps of `OutputSteps` give them: each pixel's alpha clipped to 0 to 1, its colour
// unpremultiplied (a pixel of alpha 0 has colour 0), converted, premultiplied again, and its alpha written as it is
// where the output keeps alpha and as 1 where it does not. `steps` 0 clips each channel to 0 to 1, and 1 decodes each
// channel by the sRGB transfer, takes the linear values to the space's primaries by `fromLinearSRGB`, clips them to 0
// to 1 and encodes them by `transfer`, 0 the sRGB transfer and 1 the inverse of the BT.1886 EOTF. Each component is
// written as round(V × (2^n - 1)) of its value V clipped to 0 to 1, half way away from zero: `eight` packs blue,
// green, red and alpha of eight bits into one word, lowest byte first, and `sixteen` writes red, green, blue and alpha
// of sixteen bits. Arithmetic is IEEE single precision with no fast math.
enum OutputKernelSource {
    static let text = """
        #include <metal_stdlib>
        using namespace metal;

        struct Output {
            float3x3 fromLinearSRGB;
            uint steps;
            uint transfer;
            uint keepsAlpha;
        };

        static float decodedSRGB(float encoded) {
            float magnitude = fabs(encoded);
            if (magnitude <= 0.04045f) {
                return encoded / 12.92f;
            }
            return copysign(precise::pow((magnitude + 0.055f) / 1.055f, 2.4f), encoded);
        }

        static float encodedOutput(float linear, uint transfer) {
            if (transfer == 1) {
                return precise::pow(linear, 1.0f / 2.4f);
            }
            if (linear <= 0.0031308f) {
                return 12.92f * linear;
            }
            return 1.055f * precise::pow(linear, 1.0f / 2.4f) - 0.055f;
        }

        static float4 converted(float4 pixel, constant Output &output) {
            float alpha = clamp(pixel.a, 0.0f, 1.0f);
            float3 color = float3(0.0f);
            if (alpha > 0.0f) {
                float3 encoded = pixel.rgb / alpha;
                float3 value;
                if (output.steps == 0) {
                    value = clamp(encoded, 0.0f, 1.0f);
                } else {
                    float3 linear = output.fromLinearSRGB
                        * float3(decodedSRGB(encoded.r), decodedSRGB(encoded.g), decodedSRGB(encoded.b));
                    linear = clamp(linear, 0.0f, 1.0f);
                    value = float3(
                        encodedOutput(linear.r, output.transfer),
                        encodedOutput(linear.g, output.transfer),
                        encodedOutput(linear.b, output.transfer)
                    );
                }
                color = value * alpha;
            }
            return float4(color, output.keepsAlpha != 0 ? alpha : 1.0f);
        }

        static uint code(float value, float top) {
            return uint(round(clamp(value, 0.0f, 1.0f) * top));
        }

        kernel void eight(
            texture2d<half, access::read> frame [[texture(0)]],
            texture2d<uint, access::write> output [[texture(1)]],
            constant Output &steps [[buffer(0)]],
            uint2 position [[thread_position_in_grid]]
        ) {
            if (position.x >= output.get_width() || position.y >= output.get_height()) {
                return;
            }
            float4 value = converted(float4(frame.read(position)), steps);
            uint word = code(value.b, 255.0f) | code(value.g, 255.0f) << 8 | code(value.r, 255.0f) << 16
                | code(value.a, 255.0f) << 24;
            output.write(uint4(word, 0, 0, 0), position);
        }

        kernel void sixteen(
            texture2d<half, access::read> frame [[texture(0)]],
            texture2d<ushort, access::write> output [[texture(1)]],
            constant Output &steps [[buffer(0)]],
            uint2 position [[thread_position_in_grid]]
        ) {
            if (position.x >= output.get_width() || position.y >= output.get_height()) {
                return;
            }
            float4 value = converted(float4(frame.read(position)), steps);
            output.write(
                ushort4(
                    code(value.r, 65535.0f),
                    code(value.g, 65535.0f),
                    code(value.b, 65535.0f),
                    code(value.a, 65535.0f)
                ),
                position
            );
        }
        """
}
