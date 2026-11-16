//
//  FilterKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

// The Metal functions of the filter operations of FRAMES-15, on sRGB-encoded premultiplied samples. A colour
// operation unpremultiplies, computes on v, clamps v to 0 to 1 and premultiplies by the alpha it was given.
enum FilterKernelSource {
    static let text = """
        static inline float filterLuma(float3 v) {
            return dot(v, float3(0.2126, 0.7152, 0.0722));
        }

        // IEC 61966-2-1 decoding to linear light, and encoding back.
        static inline float3 filterDecode(float3 v) {
            return select(pow((v + 0.055) / 1.055, 2.4), v / 12.92, v <= 0.04045);
        }

        static inline float3 filterEncode(float3 light) {
            return select(1.055 * pow(light, 1.0 / 2.4) - 0.055, 12.92 * light, light <= 0.0031308);
        }

        static inline float4 filterFinish(float3 v, float alpha) {
            return premultiply(float4(clamp(v, 0.0, 1.0), alpha));
        }

        // Clamps a premultiplied result so that alpha and the unpremultiplied colour lie in 0 to 1.
        static inline float4 filterClampPremultiplied(float4 value) {
            float alpha = clamp(value.a, 0.0, 1.0);

            return float4(clamp(value.rgb, 0.0, alpha), alpha);
        }

        // lowbias32 by Chris Wellons.
        static inline uint filterHash(uint value) {
            value ^= value >> 16;
            value *= 0x7feb352dU;
            value ^= value >> 15;
            value *= 0x846ca68bU;
            value ^= value >> 16;

            return value;
        }

        // Uniform on [-sqrt(3), sqrt(3)], so its standard deviation is 1.
        static inline float filterNoise(int2 grain, uint seed) {
            uint hash = filterHash(as_type<uint>(grain.x) ^ filterHash(as_type<uint>(grain.y) ^ filterHash(seed)));
            float uniform = (float(hash >> 8) + 0.5) / 16777216.0;

            return sqrt(3.0) * (2.0 * uniform - 1.0);
        }

        static inline float3 filterTableEntry(sampler table, float3 index, float size) {
            float2 texel = float2(index.r, index.g + index.b * size) + 0.5;

            return table.sample(table.transform(texel)).rgb;
        }

        [[stitchable]] float4 filterClamp(sample_t sample) {
            return filterClampPremultiplied(sample);
        }

        [[stitchable]] float4 filterExposure(sample_t sample, float ev) {
            float4 v = unpremultiply(sample);

            return filterFinish(filterEncode(filterDecode(v.rgb) * exp2(ev)), v.a);
        }

        [[stitchable]] float4 filterTemperature(sample_t sample, float3 gain) {
            float4 v = unpremultiply(sample);

            return filterFinish(filterEncode(filterDecode(v.rgb) * gain), v.a);
        }

        [[stitchable]] float4 filterContrast(sample_t sample, float amount) {
            float4 v = unpremultiply(sample);

            return filterFinish((v.rgb - 0.5) * amount + 0.5, v.a);
        }

        [[stitchable]] float4 filterSaturation(sample_t sample, float amount) {
            float4 v = unpremultiply(sample);
            float luma = filterLuma(v.rgb);

            return filterFinish(luma + amount * (v.rgb - luma), v.a);
        }

        // The hue-rotate() matrix of W3C Filter Effects.
        [[stitchable]] float4 filterHue(sample_t sample, float degrees) {
            float4 v = unpremultiply(sample);
            float c = cos(degrees * M_PI_F / 180.0);
            float s = sin(degrees * M_PI_F / 180.0);
            float3 red = float3(0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928);
            float3 green = float3(0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283);
            float3 blue = float3(0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072);

            return filterFinish(float3(dot(red, v.rgb), dot(green, v.rgb), dot(blue, v.rgb)), v.a);
        }

        // The sepia() matrix of W3C Filter Effects.
        [[stitchable]] float4 filterSepia(sample_t sample, float amount) {
            float4 v = unpremultiply(sample);
            float rest = 1.0 - amount;
            float3 red = float3(0.393 + 0.607 * rest, 0.769 - 0.769 * rest, 0.189 - 0.189 * rest);
            float3 green = float3(0.349 - 0.349 * rest, 0.686 + 0.314 * rest, 0.168 - 0.168 * rest);
            float3 blue = float3(0.272 - 0.272 * rest, 0.534 - 0.534 * rest, 0.131 + 0.869 * rest);

            return filterFinish(float3(dot(red, v.rgb), dot(green, v.rgb), dot(blue, v.rgb)), v.a);
        }

        // `input` and `output` are each a black and a white level.
        [[stitchable]] float4 filterLevels(sample_t sample, float2 input, float2 output) {
            float4 v = unpremultiply(sample);
            float3 level = clamp((v.rgb - input.x) / (input.y - input.x), 0.0, 1.0);

            return filterFinish(output.x + level * (output.y - output.x), v.a);
        }

        // `table` holds the entries of a `size` cube as `size` columns of red by `size` x `size` rows of green plus
        // blue times `size`, at texel centres.
        [[stitchable]] float4 filterLookUp(
            sampler image,
            sampler table,
            float size,
            float3 domainMin,
            float3 domainMax,
            float amount,
            destination dest
        ) {
            float4 v = unpremultiply(image.sample(image.transform(dest.coord())));
            float3 index = clamp((v.rgb - domainMin) / (domainMax - domainMin), 0.0, 1.0) * (size - 1.0);
            float3 lower = min(floor(index), size - 2.0);
            float3 fraction = index - lower;
            float3 c00 = mix(
                filterTableEntry(table, lower, size),
                filterTableEntry(table, lower + float3(1, 0, 0), size),
                fraction.r
            );
            float3 c10 = mix(
                filterTableEntry(table, lower + float3(0, 1, 0), size),
                filterTableEntry(table, lower + float3(1, 1, 0), size),
                fraction.r
            );
            float3 c01 = mix(
                filterTableEntry(table, lower + float3(0, 0, 1), size),
                filterTableEntry(table, lower + float3(1, 0, 1), size),
                fraction.r
            );
            float3 c11 = mix(
                filterTableEntry(table, lower + float3(0, 1, 1), size),
                filterTableEntry(table, lower + float3(1, 1, 1), size),
                fraction.r
            );
            float3 mapped = mix(mix(c00, c10, fraction.g), mix(c01, c11, fraction.g), fraction.b);

            return filterFinish(mix(v.rgb, mapped, amount), v.a);
        }

        // `blurred` is the Gaussian blur of `sample`'s image, both premultiplied.
        [[stitchable]] float4 filterSharpen(sample_t sample, sample_t blurred, float amount) {
            return filterClampPremultiplied(sample + amount * (sample - blurred));
        }

        [[stitchable]] float4 filterBloomBright(sample_t sample) {
            return sample * smoothstep(0.5, 1.0, filterLuma(unpremultiply(sample).rgb));
        }

        // `glow` is the blur of the bright parts, and `tint` the bloom's colour premultiplied, or white.
        [[stitchable]] float4 filterBloomAdd(sample_t sample, sample_t glow, float amount, float4 tint) {
            return filterClampPremultiplied(sample + amount * glow * tint);
        }

        // `centre` is the centre of the image's extent and `halfDiagonal` half its diagonal. smoothstep(1, 1, d) is
        // taken as its limit, a step at 1.
        [[stitchable]] float4 filterVignette(
            sample_t sample,
            float amount,
            float radius,
            float2 centre,
            float halfDiagonal,
            destination dest
        ) {
            float4 v = unpremultiply(sample);
            float reach = length(dest.coord() - centre) / halfDiagonal;
            float falloff = radius < 1.0 ? smoothstep(radius, 1.0, reach) : step(1.0, reach);

            return filterFinish(v.rgb * (1.0 - amount * falloff), v.a);
        }

        // Grains are squares `size` across on a grid from `topLeft`, the extent's top left corner. `seed` is the
        // seed's low and high sixteen bits.
        [[stitchable]] float4 filterGrain(
            sample_t sample,
            float amount,
            float size,
            float2 topLeft,
            float2 seed,
            destination dest
        ) {
            float4 v = unpremultiply(sample);
            float2 place = float2(dest.coord().x - topLeft.x, topLeft.y - dest.coord().y);
            float noise = filterNoise(int2(floor(place / size)), uint(seed.x) | (uint(seed.y) << 16));
            float luma = filterLuma(v.rgb);

            return filterFinish(v.rgb + amount * 4.0 * luma * (1.0 - luma) * noise, v.a);
        }

        // One output pixel per block, block (column, row) counted from the top left: the mean of the image's pixels
        // whose centres lie in the block. `extent` is the image's origin and size.
        [[stitchable]] float4 filterBlockMean(sampler image, float size, float4 extent, destination dest) {
            float2 block = floor(dest.coord());
            int firstColumn = max(int(floor(block.x * size - 0.5)), 0);
            int lastColumn = min(int(ceil((block.x + 1.0) * size - 0.5)), int(extent.z) - 1);
            int firstRow = max(int(floor(block.y * size - 0.5)), 0);
            int lastRow = min(int(ceil((block.y + 1.0) * size - 0.5)), int(extent.w) - 1);
            float4 sum = float4(0.0);
            float count = 0.0;
            for (int row = firstRow; row <= lastRow; row++) {
                if (floor((float(row) + 0.5) / size) != block.y) {
                    continue;
                }
                for (int column = firstColumn; column <= lastColumn; column++) {
                    if (floor((float(column) + 0.5) / size) != block.x) {
                        continue;
                    }
                    float2 centre = float2(extent.x + float(column) + 0.5, extent.y + extent.w - float(row) - 0.5);
                    sum += image.sample(image.transform(centre));
                    count += 1.0;
                }
            }

            return count > 0.0 ? sum / count : float4(0.0);
        }

        // Fills each pixel with its block's mean from `blocks`, as filterBlockMean lays them out.
        [[stitchable]] float4 filterBlockFill(sampler blocks, float size, float4 extent, destination dest) {
            float2 place = float2(dest.coord().x - extent.x, extent.y + extent.w - dest.coord().y);

            return blocks.sample(blocks.transform(floor(place / size) + 0.5));
        }
        """
}
