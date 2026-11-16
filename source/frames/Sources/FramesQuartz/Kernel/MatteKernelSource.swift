//
//  MatteKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

// The Metal function of the luma matte kernel. L is the Rec. 709 luma of the matte's unpremultiplied sRGB-encoded
// values, 1 - L when inverted, and the premultiplied picture is multiplied by clamp((p (1 + s) - L) / s, 0, 1). At a
// softness of 0 that is its limit: 1 below the progress, the progress at it and 0 above.
enum MatteKernelSource {
    static let text = """
        [[stitchable]] float4 matteLuma(sample_t picture, sample_t matte, float progress, float softness, float inverted) {
            float3 color = matte.a > 0.0 ? matte.rgb / matte.a : float3(0.0);
            float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
            if (inverted > 0.5) {
                luma = 1.0 - luma;
            }
            float shown;
            if (softness > 0.0) {
                shown = clamp((progress * (1.0 + softness) - luma) / softness, 0.0, 1.0);
            } else {
                shown = luma < progress ? 1.0 : (luma > progress ? 0.0 : progress);
            }
            return picture * shown;
        }
        """
}
