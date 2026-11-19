//
//  TrackMatteKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/18/26.
//

// The Metal function of the track matte kernel, on a premultiplied source on the encoded form: its alpha, or the
// Rec. 709 luma of its unpremultiplied values clamped to 0 to 1 times its alpha, so a transparent source gives 0 and a
// part brighter than reference white counts as white. 1 minus that when inverted.
enum TrackMatteKernelSource {
    static let text = """
        [[stitchable]] float4 trackMatte(sample_t source, float luma, float inverted) {
            float3 color = source.a > 0.0 ? source.rgb / source.a : float3(0.0);
            float value = luma > 0.5 ? clamp(formLuma(color, 0.0), 0.0, 1.0) * source.a : source.a;
            if (inverted > 0.5) {
                value = 1.0 - value;
            }
            return float4(value, value, value, 1.0);
        }
        """
}
