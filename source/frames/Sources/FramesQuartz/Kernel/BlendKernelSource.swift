//
//  BlendKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

// The Metal functions of the blend mode kernels, each taking the premultiplied source and backdrop samples in the form
// its `linear` argument names (`FormKernelSource`). They follow W3C Compositing and Blending Level 1 as FRAMES-26
// reads it: the mode's B(Cb, Cs) on unpremultiplied colours as they are, unbounded, composited by
// co = cs (1 - ab) + cb (1 - as) + as ab B(Cb, Cs) and ao = as + ab (1 - as) in the samples' form. The blend
// functions of `normal`, `multiply`, `screen`, `darken`, `lighten`, `difference`, `color-dodge`, `color-burn` and `add`
// are computed in that form, and those of `overlay`, `hard-light`, `soft-light`, `exclusion` and the non-separable
// modes on the encoded form, their result taken back. `add` sums the premultiplied samples without bound, and
// `plus-lighter` sums them and bounds them by 1. The non-separable modes follow W3C's Lum, Sat, SetLum, SetSat and
// ClipColor as written, so ClipColor's second step uses the maximum taken before its first, and ClipColor returns a
// colour as it is where it would divide by 0.
enum BlendKernelSource {
    static let text = """
        inline float3 blendUnpremultiplied(float4 sample) {
            return sample.a > 0.0 ? sample.rgb / sample.a : float3(0.0);
        }

        inline float4 blendComposite(float4 source, float4 backdrop, float3 mixed) {
            float3 color = source.rgb * (1.0 - backdrop.a)
                + backdrop.rgb * (1.0 - source.a)
                + source.a * backdrop.a * mixed;
            return float4(color, source.a + backdrop.a * (1.0 - source.a));
        }

        // The composite of a blend function computed on the encoded form, its result taken to the samples' form.
        inline float4 blendCompositeEncoded(float4 source, float4 backdrop, float3 mixed, float linear) {
            return blendComposite(source, backdrop, formFromEncoded(mixed, linear));
        }

        inline float3 blendEncoded(float4 sample, float linear) {
            return formToEncoded(blendUnpremultiplied(sample), linear);
        }

        inline float3 blendHardLightColor(float3 backdrop, float3 source) {
            float3 multiplied = backdrop * 2.0 * source;
            float3 screened = backdrop + (2.0 * source - 1.0) - backdrop * (2.0 * source - 1.0);
            return select(screened, multiplied, source <= 0.5);
        }

        inline float blendColorDodgeChannel(float backdrop, float source) {
            if (backdrop == 0.0) {
                return 0.0;
            }
            if (source == 1.0) {
                return 1.0;
            }
            return min(1.0, backdrop / (1.0 - source));
        }

        inline float blendColorBurnChannel(float backdrop, float source) {
            if (backdrop == 1.0) {
                return 1.0;
            }
            if (source == 0.0) {
                return 0.0;
            }
            return 1.0 - min(1.0, (1.0 - backdrop) / source);
        }

        inline float blendSoftLightChannel(float backdrop, float source) {
            if (source <= 0.5) {
                return backdrop - (1.0 - 2.0 * source) * backdrop * (1.0 - backdrop);
            }
            float darkened = backdrop <= 0.25 ? ((16.0 * backdrop - 12.0) * backdrop + 4.0) * backdrop : sqrt(backdrop);
            return backdrop + (2.0 * source - 1.0) * (darkened - backdrop);
        }

        inline float blendLum(float3 color) {
            return dot(color, float3(0.3, 0.59, 0.11));
        }

        inline float blendSat(float3 color) {
            return max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        }

        inline float3 blendClipColor(float3 color) {
            float lum = blendLum(color);
            float lowest = min(color.r, min(color.g, color.b));
            float highest = max(color.r, max(color.g, color.b));
            if (lowest < 0.0 && lum > lowest) {
                color = lum + (color - lum) * lum / (lum - lowest);
            }
            if (highest > 1.0 && highest > lum) {
                color = lum + (color - lum) * (1.0 - lum) / (highest - lum);
            }
            return color;
        }

        inline float3 blendSetLum(float3 color, float lum) {
            return blendClipColor(color + (lum - blendLum(color)));
        }

        inline float3 blendSetSat(float3 color, float sat) {
            float lowest = min(color.r, min(color.g, color.b));
            float highest = max(color.r, max(color.g, color.b));
            if (highest <= lowest) {
                return float3(0.0);
            }
            return (color - lowest) * sat / (highest - lowest);
        }

        [[stitchable]] float4 blendNormal(sample_t source, sample_t backdrop, float linear) {
            return blendComposite(source, backdrop, blendUnpremultiplied(source));
        }

        [[stitchable]] float4 blendMultiply(sample_t source, sample_t backdrop, float linear) {
            return blendComposite(source, backdrop, blendUnpremultiplied(backdrop) * blendUnpremultiplied(source));
        }

        [[stitchable]] float4 blendScreen(sample_t source, sample_t backdrop, float linear) {
            float3 cb = blendUnpremultiplied(backdrop);
            float3 cs = blendUnpremultiplied(source);
            return blendComposite(source, backdrop, cb + cs - cb * cs);
        }

        [[stitchable]] float4 blendOverlay(sample_t source, sample_t backdrop, float linear) {
            float3 mixed = blendHardLightColor(blendEncoded(source, linear), blendEncoded(backdrop, linear));
            return blendCompositeEncoded(source, backdrop, mixed, linear);
        }

        [[stitchable]] float4 blendDarken(sample_t source, sample_t backdrop, float linear) {
            return blendComposite(source, backdrop, min(blendUnpremultiplied(backdrop), blendUnpremultiplied(source)));
        }

        [[stitchable]] float4 blendLighten(sample_t source, sample_t backdrop, float linear) {
            return blendComposite(source, backdrop, max(blendUnpremultiplied(backdrop), blendUnpremultiplied(source)));
        }

        [[stitchable]] float4 blendColorDodge(sample_t source, sample_t backdrop, float linear) {
            float3 cb = blendUnpremultiplied(backdrop);
            float3 cs = blendUnpremultiplied(source);
            float3 mixed = float3(
                blendColorDodgeChannel(cb.r, cs.r),
                blendColorDodgeChannel(cb.g, cs.g),
                blendColorDodgeChannel(cb.b, cs.b)
            );
            return blendComposite(source, backdrop, mixed);
        }

        [[stitchable]] float4 blendColorBurn(sample_t source, sample_t backdrop, float linear) {
            float3 cb = blendUnpremultiplied(backdrop);
            float3 cs = blendUnpremultiplied(source);
            float3 mixed = float3(
                blendColorBurnChannel(cb.r, cs.r),
                blendColorBurnChannel(cb.g, cs.g),
                blendColorBurnChannel(cb.b, cs.b)
            );
            return blendComposite(source, backdrop, mixed);
        }

        [[stitchable]] float4 blendHardLight(sample_t source, sample_t backdrop, float linear) {
            float3 mixed = blendHardLightColor(blendEncoded(backdrop, linear), blendEncoded(source, linear));
            return blendCompositeEncoded(source, backdrop, mixed, linear);
        }

        [[stitchable]] float4 blendSoftLight(sample_t source, sample_t backdrop, float linear) {
            float3 cb = blendEncoded(backdrop, linear);
            float3 cs = blendEncoded(source, linear);
            float3 mixed = float3(
                blendSoftLightChannel(cb.r, cs.r),
                blendSoftLightChannel(cb.g, cs.g),
                blendSoftLightChannel(cb.b, cs.b)
            );
            return blendCompositeEncoded(source, backdrop, mixed, linear);
        }

        [[stitchable]] float4 blendDifference(sample_t source, sample_t backdrop, float linear) {
            return blendComposite(source, backdrop, abs(blendUnpremultiplied(backdrop) - blendUnpremultiplied(source)));
        }

        [[stitchable]] float4 blendExclusion(sample_t source, sample_t backdrop, float linear) {
            float3 cb = blendEncoded(backdrop, linear);
            float3 cs = blendEncoded(source, linear);
            return blendCompositeEncoded(source, backdrop, cb + cs - 2.0 * cb * cs, linear);
        }

        [[stitchable]] float4 blendPlusLighter(sample_t source, sample_t backdrop, float linear) {
            return min(float4(1.0), source + backdrop);
        }

        [[stitchable]] float4 blendAdd(sample_t source, sample_t backdrop, float linear) {
            return float4(source.rgb + backdrop.rgb, source.a + backdrop.a * (1.0 - source.a));
        }

        [[stitchable]] float4 blendHue(sample_t source, sample_t backdrop, float linear) {
            float3 cb = blendEncoded(backdrop, linear);
            float3 cs = blendEncoded(source, linear);
            float3 mixed = blendSetLum(blendSetSat(cs, blendSat(cb)), blendLum(cb));
            return blendCompositeEncoded(source, backdrop, mixed, linear);
        }

        [[stitchable]] float4 blendSaturation(sample_t source, sample_t backdrop, float linear) {
            float3 cb = blendEncoded(backdrop, linear);
            float3 cs = blendEncoded(source, linear);
            float3 mixed = blendSetLum(blendSetSat(cb, blendSat(cs)), blendLum(cb));
            return blendCompositeEncoded(source, backdrop, mixed, linear);
        }

        [[stitchable]] float4 blendColor(sample_t source, sample_t backdrop, float linear) {
            float3 cb = blendEncoded(backdrop, linear);
            float3 mixed = blendSetLum(blendEncoded(source, linear), blendLum(cb));
            return blendCompositeEncoded(source, backdrop, mixed, linear);
        }

        [[stitchable]] float4 blendLuminosity(sample_t source, sample_t backdrop, float linear) {
            float3 cs = blendEncoded(source, linear);
            float3 mixed = blendSetLum(blendEncoded(backdrop, linear), blendLum(cs));
            return blendCompositeEncoded(source, backdrop, mixed, linear);
        }
        """
}
