//
//  WorkingKernelSource.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

// The Metal compute functions that take a decoded frame to working values, as the steps of `ConversionSteps` give
// them: each output pixel at (x, y), rows top first, is the stored pixel at floor(`placement` × (x + 0.5, y + 0.5) +
// `offset`). `working` reads R'G'B' half floats, unpremultiplies them, converts them, premultiplies them again and
// writes half floats, its alpha kept and a pixel of alpha 0 written as 0. `workingYCbCr` reads a plane of luma and a
// plane of interleaved Cb and Cr code values, each shifted down by `shift`, takes chroma at the luma sample's centre by
// straight lines between the four chroma samples nearest it, chroma sample (i, j) standing at `siting` + `subsampling`
// × (i, j) in luma pixels and an edge sample repeated past the edge, takes the code values to Y'CbCr by the range's
// offsets and scales and to R'G'B' by the matrix's constants KR and KB (FRAMES-21 Rules), and converts them with alpha
// 1. `steps` 0 is the identity, which keeps the R'G'B', and 1 decodes each channel by `decodeTable`, takes the linear
// values by `toLinearSRGB` and encodes them by the sRGB transfer. The table holds the decoded value of each half float
// by its bit pattern, and a value between two half floats is decoded by the straight line between theirs, so a half
// float's value is the table's. Arithmetic is IEEE single precision with no fast math.
enum WorkingKernelSource {
    static let text = """
        #include <metal_stdlib>
        using namespace metal;

        struct Placement {
            float2x2 placement;
            float2 offset;
            uint steps;
        };

        struct YCbCr {
            float lumaOffset;
            float lumaScale;
            float chromaOffset;
            float chromaScale;
            float2 siting;
            float2 subsampling;
            float lumaRed;
            float lumaBlue;
            float lumaGreen;
            ushort shift;
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

        static float3 converted(
            float3 encoded,
            uint steps,
            constant float3x3 &toLinearSRGB,
            device const float *decodeTable
        ) {
            if (steps == 0) {
                return encoded;
            }
            float3 linear = float3(
                decoded(encoded.r, decodeTable),
                decoded(encoded.g, decodeTable),
                decoded(encoded.b, decodeTable)
            );
            float3 converted = toLinearSRGB * linear;
            return float3(encodedSRGB(converted.r), encodedSRGB(converted.g), encodedSRGB(converted.b));
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
            float3 working = converted(pixel.rgb / alpha, placement.steps, toLinearSRGB, decodeTable);
            output.write(half4(float4(working * alpha, alpha)), position);
        }

        kernel void workingYCbCr(
            texture2d<ushort, access::read> luma [[texture(0)]],
            texture2d<ushort, access::read> chroma [[texture(1)]],
            texture2d<half, access::write> output [[texture(2)]],
            constant Placement &placement [[buffer(0)]],
            constant float3x3 &toLinearSRGB [[buffer(1)]],
            device const float *decodeTable [[buffer(2)]],
            constant YCbCr &yCbCr [[buffer(3)]],
            uint2 position [[thread_position_in_grid]]
        ) {
            if (position.x >= output.get_width() || position.y >= output.get_height()) {
                return;
            }
            uint2 source = uint2(floor(placement.placement * (float2(position) + 0.5f) + placement.offset));
            float lumaCode = float(luma.read(source).r >> yCbCr.shift);

            float2 at = (float2(source) + 0.5f - yCbCr.siting) / yCbCr.subsampling;
            float2 base = floor(at);
            float2 weight = at - base;
            int2 last = int2(chroma.get_width(), chroma.get_height()) - 1;
            int2 first = clamp(int2(base), int2(0), last);
            int2 second = clamp(int2(base) + 1, int2(0), last);
            ushort2 shift = ushort2(yCbCr.shift);
            float2 topLeft = float2(chroma.read(uint2(first.x, first.y)).rg >> shift);
            float2 topRight = float2(chroma.read(uint2(second.x, first.y)).rg >> shift);
            float2 bottomLeft = float2(chroma.read(uint2(first.x, second.y)).rg >> shift);
            float2 bottomRight = float2(chroma.read(uint2(second.x, second.y)).rg >> shift);
            float2 upper = topLeft + (topRight - topLeft) * weight.x;
            float2 lower = bottomLeft + (bottomRight - bottomLeft) * weight.x;
            float2 chromaCode = upper + (lower - upper) * weight.y;

            float y = (lumaCode - yCbCr.lumaOffset) / yCbCr.lumaScale;
            float2 cbcr = (chromaCode - yCbCr.chromaOffset) / yCbCr.chromaScale;
            float red = y + 2.0f * (1.0f - yCbCr.lumaRed) * cbcr.y;
            float blue = y + 2.0f * (1.0f - yCbCr.lumaBlue) * cbcr.x;
            float green = (y - yCbCr.lumaRed * red - yCbCr.lumaBlue * blue) / yCbCr.lumaGreen;
            float3 working = converted(float3(red, green, blue), placement.steps, toLinearSRGB, decodeTable);
            output.write(half4(float4(working, 1.0f)), position);
        }
        """
}
