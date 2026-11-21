//
//  CornerPinKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/21/26.
//

// The Metal functions of the corner pin warp (FRAMES-27), on premultiplied samples in either form, which they only
// average. The source's bilinear reconstruction, transparent outside, is the reconstruction of the source with its edge
// pixels extended outward, times its coverage: clamp(t + 0.5, 0, 1) for each edge, t a point's depth inside that edge,
// so the reconstruction ramps over one source pixel, half of it outside. `cornerPinHalve` makes one level of a two by
// two box pyramid of the extended source: each pixel the mean of the four pixels it covers in the level below.
// `cornerPinWarp` gives each output pixel the mean of four by four subsamples over its square. Each is carried back
// through the inverse map, rows `rowX`, `rowY` and `rowW`, to a point of the source, `size` wide and high from its
// origin, and covers there the parallelogram centred on it whose sides are the steps to the next subsamples to its
// right and below. It is the pyramid read trilinearly at the level where neighbouring subsamples land at most one level
// pixel apart, times the mean of the coverage over its parallelogram, so a shrunk picture is area sampled up to its
// edges, and a constant source keeps its value wherever the subsamples' parallelograms lie inside it. A subsample whose
// w is 0 or below lies at or beyond the horizon and adds nothing.
enum CornerPinKernelSource {
    static let text = """
        // The first and second integrals of the coverage clamp(t + 0.5, 0, 1), from 0 at t = -0.5.
        static inline float cornerPinCoverageIntegral(float t) {
            if (t <= -0.5) {
                return 0.0;
            }
            if (t < 0.5) {
                float u = t + 0.5;
                return u * u * 0.5;
            }
            return t;
        }

        static inline float cornerPinCoverageSecondIntegral(float t) {
            if (t <= -0.5) {
                return 0.0;
            }
            if (t < 0.5) {
                float u = t + 0.5;
                return u * u * u / 6.0;
            }
            return t * t * 0.5 + 1.0 / 24.0;
        }

        // The mean of the coverage at depth t inside one edge, over the sum of two boxes `a` and `b` wide, which is how
        // a parallelogram spreads over the axis across that edge.
        static inline float cornerPinCoverage(float t, float a, float b) {
            float wide = max(a, b);
            float narrow = min(a, b);
            float reach = 0.5 * (wide + narrow);
            if (t - reach >= 0.5) {
                return 1.0;
            }
            if (t + reach <= -0.5) {
                return 0.0;
            }
            if (wide < 1.0e-3) {
                return clamp(t + 0.5, 0.0, 1.0);
            }
            float halfWide = 0.5 * wide;
            if (narrow < 1.0e-2 * wide) {
                return (cornerPinCoverageIntegral(t + halfWide) - cornerPinCoverageIntegral(t - halfWide)) / wide;
            }
            float halfNarrow = 0.5 * narrow;
            return (cornerPinCoverageSecondIntegral(t + halfWide + halfNarrow)
                - cornerPinCoverageSecondIntegral(t + halfWide - halfNarrow)
                - cornerPinCoverageSecondIntegral(t - halfWide + halfNarrow)
                + cornerPinCoverageSecondIntegral(t - halfWide - halfNarrow)) / (wide * narrow);
        }

        static inline float4 cornerPinTap(
            int level,
            float2 point,
            sampler level0,
            sampler level1,
            sampler level2,
            sampler level3,
            sampler level4,
            sampler level5,
            sampler level6
        ) {
            float2 at = point / float(1 << level);
            switch (level) {
                case 0: return level0.sample(level0.transform(at));
                case 1: return level1.sample(level1.transform(at));
                case 2: return level2.sample(level2.transform(at));
                case 3: return level3.sample(level3.transform(at));
                case 4: return level4.sample(level4.transform(at));
                case 5: return level5.sample(level5.transform(at));
                default: return level6.sample(level6.transform(at));
            }
        }

        [[stitchable]] float4 cornerPinHalve(sampler image, destination dest) {
            float2 point = dest.coord() * 2.0;

            return (image.sample(image.transform(point + float2(-0.5, -0.5)))
                + image.sample(image.transform(point + float2(0.5, -0.5)))
                + image.sample(image.transform(point + float2(-0.5, 0.5)))
                + image.sample(image.transform(point + float2(0.5, 0.5)))) * 0.25;
        }

        [[stitchable]] float4 cornerPinWarp(
            sampler level0,
            sampler level1,
            sampler level2,
            sampler level3,
            sampler level4,
            sampler level5,
            sampler level6,
            float3 rowX,
            float3 rowY,
            float3 rowW,
            float2 size,
            destination dest
        ) {
            const int count = 4;
            const float step = 1.0 / float(count);
            const float top = 6.0;
            float2 origin = floor(dest.coord());
            float4 sum = float4(0.0);
            for (int row = 0; row < count; row++) {
                for (int column = 0; column < count; column++) {
                    float3 point = float3(origin + (float2(column, row) + 0.5) * step, 1.0);
                    float w = dot(rowW, point);
                    if (w <= 0.0) {
                        continue;
                    }
                    float2 source = float2(dot(rowX, point), dot(rowY, point)) / w;

                    float3 right = point + float3(step, 0.0, 0.0);
                    float3 below = point + float3(0.0, step, 0.0);
                    float wRight = dot(rowW, right);
                    float wBelow = dot(rowW, below);
                    float level = top;
                    float2 across = float2(0.0);
                    float2 down = float2(0.0);
                    if (wRight > 0.0 && wBelow > 0.0) {
                        across = float2(dot(rowX, right), dot(rowY, right)) / wRight - source;
                        down = float2(dot(rowX, below), dot(rowY, below)) / wBelow - source;
                        float spacing = max(length(across), length(down));
                        if (isfinite(spacing)) {
                            level = clamp(log2(max(spacing, 1.0e-6)), 0.0, top);
                        } else {
                            across = float2(0.0);
                            down = float2(0.0);
                        }
                    }

                    float2 a = abs(across);
                    float2 b = abs(down);
                    float coverage = cornerPinCoverage(source.x, a.x, b.x)
                        * cornerPinCoverage(size.x - source.x, a.x, b.x)
                        * cornerPinCoverage(source.y, a.y, b.y)
                        * cornerPinCoverage(size.y - source.y, a.y, b.y);
                    if (coverage <= 0.0) {
                        continue;
                    }

                    float2 at = clamp(source, float2(-1.0), size + 1.0);
                    int lower = int(floor(level));
                    float fraction = level - float(lower);
                    float4 value = cornerPinTap(lower, at, level0, level1, level2, level3, level4, level5, level6);
                    if (fraction > 0.0 && lower < 6) {
                        float4 upper = cornerPinTap(lower + 1, at, level0, level1, level2, level3, level4, level5, level6);
                        value = mix(value, upper, fraction);
                    }
                    sum += value * coverage;
                }
            }

            return sum / float(count * count);
        }
        """
}
