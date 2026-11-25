//
//  WorkingKernelSource.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

// The Metal compute function that takes a decoded frame's R'G'B' half floats to working values, as the steps of
// `ConversionSteps` give them: each output pixel at (x, y), rows top first, is the stored pixel at
// floor(`placement` × (x + 0.5, y + 0.5) + `offset`), unpremultiplied, converted, premultiplied again and written as
// half floats, its alpha kept and a pixel of alpha 0 written as 0. `steps` 0 is the identity, which copies the pixel,
// and 1 decodes each channel by `decodeTable`, takes the linear values by `toLinearSRGB` and encodes them by the sRGB
// transfer. The table holds the decoded value of each half float by its bit pattern, and a value between two half
// floats is decoded by the straight line between theirs, so a half float's value is the table's. Arithmetic is IEEE
// single precision with no fast math.
enum WorkingKernelSource {
    static let text = """
        #include <metal_stdlib>
        using namespace metal;

        struct Placement {
            float2x2 placement;
            float2 offset;
            uint steps;
        };

        static float decoded(float value, device const float *decodeTable) {
            half rounded = half(value);
            ushort bits = as_type<ushort>(rounded);
            float near = float(rounded);
            if (near == value || isinf(near) || isnan(value)) {
                return decodeTable[bits];
            }
            bool negative = (bits & 0x8000) != 0;
            ushort other;
            if (value > near) {
                other = negative ? (bits == 0x8000 ? 0x0001 : bits - 1) : bits + 1;
            } else {
                other = negative ? bits + 1 : (bits == 0x0000 ? 0x8001 : bits - 1);
            }
            float far = float(as_type<half>(other));
            if (isinf(far)) {
                return decodeTable[bits];
            }
            float t = (value - near) / (far - near);
            return decodeTable[bits] + (decodeTable[other] - decodeTable[bits]) * t;
        }

        static float encodedSRGB(float linear) {
            float magnitude = fabs(linear);
            if (magnitude <= 0.0031308f) {
                return 12.92f * linear;
            }
            return copysign(1.055f * precise::pow(magnitude, 1.0f / 2.4f) - 0.055f, linear);
        }

        kernel void working(
            texture2d<half, access::read> stored [[texture(0)]],
            texture2d<half, access::write> output [[texture(1)]],
            constant Placement &placement [[buffer(0)]],
            constant float3x3 &toLinearSRGB [[buffer(1)]],
            device const float *decodeTable [[buffer(2)]],
            uint2 position [[thread_position_in_grid]]
        ) {
            if (position.x >= output.get_width() || position.y >= output.get_height()) {
                return;
            }
            float2 source = floor(placement.placement * (float2(position) + 0.5f) + placement.offset);
            float4 pixel = float4(stored.read(uint2(source)));
            if (placement.steps == 0) {
                output.write(half4(pixel), position);
                return;
            }
            float alpha = pixel.a;
            if (!(alpha > 0.0f)) {
                output.write(half4(0.0h, 0.0h, 0.0h, half(alpha)), position);
                return;
            }
            float3 encoded = pixel.rgb / alpha;
            float3 linear = float3(
                decoded(encoded.r, decodeTable),
                decoded(encoded.g, decodeTable),
                decoded(encoded.b, decodeTable)
            );
            float3 converted = toLinearSRGB * linear;
            float3 working = float3(encodedSRGB(converted.r), encodedSRGB(converted.g), encodedSRGB(converted.b));
            output.write(half4(float4(working * alpha, alpha)), position);
        }
        """
}
