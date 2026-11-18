//
//  TrackMatteKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/18/26.
//

// The Metal function of the track matte kernel, on a premultiplied sRGB-encoded source: its alpha, or the Rec. 709
// luma of its values, which premultiplied is the luma of the unpremultiplied values times the alpha, so a transparent
// source gives 0. 1 minus that when inverted. It calls `filterLuma`, so it is joined after the filter source.
enum TrackMatteKernelSource {
    static let text = """
        [[stitchable]] float4 trackMatte(sample_t source, float luma, float inverted) {
            float value = clamp(luma > 0.5 ? filterLuma(source.rgb) : source.a, 0.0, 1.0);
            if (inverted > 0.5) {
                value = 1.0 - value;
            }
            return float4(value, value, value, 1.0);
        }
        """
}
