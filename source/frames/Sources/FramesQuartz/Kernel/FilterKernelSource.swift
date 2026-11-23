//
//  FilterKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

// The Metal functions of the filter operations (FRAMES-15), on premultiplied samples in the form their `linear`
// argument names (`FormKernelSource`). A colour operation unpremultiplies, takes v to its home, computes, takes its
// result back and premultiplies by the alpha it was given, and clamps nothing: `contrast`, `saturation`, `hue`,
// `sepia`, `levels`, `lut`'s lookup in `srgb` and `grain` on the encoded form, `exposure` and `temperature` on the
// linear form, and `vignette`, `mix` and `lut`'s `amount` in the samples' form. Blur, sharpen, bloom, pixelate and
// displace work in the samples' form and clamp their alpha only; displace takes its map's values clamped to 0 to 1.
enum FilterKernelSource {
    static let text = """
        static inline float4 filterFinish(float3 v, float alpha) {
            return premultiply(float4(v, alpha));
        }

        // Clamps a premultiplied result's alpha to 0 to 1, and a pixel whose alpha is then 0 to transparent.
        static inline float4 filterClampedAlpha(float4 value) {
            float alpha = clamp(value.a, 0.0, 1.0);

            return alpha > 0.0 ? float4(value.rgb, alpha) : float4(0.0);
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

        [[stitchable]] float4 filterClampAlpha(sample_t sample) {
            return filterClampedAlpha(sample);
        }

        [[stitchable]] float4 filterExposure(sample_t sample, float ev, float linear) {
            float4 v = unpremultiply(sample);

            return filterFinish(formFromLinear(formToLinear(v.rgb, linear) * exp2(ev), linear), v.a);
        }

        [[stitchable]] float4 filterTemperature(sample_t sample, float3 gain, float linear) {
            float4 v = unpremultiply(sample);

            return filterFinish(formFromLinear(formToLinear(v.rgb, linear) * gain, linear), v.a);
        }

        [[stitchable]] float4 filterContrast(sample_t sample, float amount, float linear) {
            float4 v = unpremultiply(sample);
            float3 encoded = formToEncoded(v.rgb, linear);

            return filterFinish(formFromEncoded((encoded - 0.5) * amount + 0.5, linear), v.a);
        }

        [[stitchable]] float4 filterSaturation(sample_t sample, float amount, float linear) {
            float4 v = unpremultiply(sample);
            float3 encoded = formToEncoded(v.rgb, linear);
            float luma = dot(encoded, float3(0.2126, 0.7152, 0.0722));

            return filterFinish(formFromEncoded(luma + amount * (encoded - luma), linear), v.a);
        }

        // The hue-rotate() matrix of W3C Filter Effects.
        [[stitchable]] float4 filterHue(sample_t sample, float degrees, float linear) {
            float4 v = unpremultiply(sample);
            float3 encoded = formToEncoded(v.rgb, linear);
            float c = cos(degrees * M_PI_F / 180.0);
            float s = sin(degrees * M_PI_F / 180.0);
            float3 red = float3(0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928);
            float3 green = float3(0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283);
            float3 blue = float3(0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072);

            float3 rotated = float3(dot(red, encoded), dot(green, encoded), dot(blue, encoded));

            return filterFinish(formFromEncoded(rotated, linear), v.a);
        }

        // The sepia() matrix of W3C Filter Effects.
        [[stitchable]] float4 filterSepia(sample_t sample, float amount, float linear) {
            float4 v = unpremultiply(sample);
            float3 encoded = formToEncoded(v.rgb, linear);
            float rest = 1.0 - amount;
            float3 red = float3(0.393 + 0.607 * rest, 0.769 - 0.769 * rest, 0.189 - 0.189 * rest);
            float3 green = float3(0.349 - 0.349 * rest, 0.686 + 0.314 * rest, 0.168 - 0.168 * rest);
            float3 blue = float3(0.272 - 0.272 * rest, 0.534 - 0.534 * rest, 0.131 + 0.869 * rest);

            float3 toned = float3(dot(red, encoded), dot(green, encoded), dot(blue, encoded));

            return filterFinish(formFromEncoded(toned, linear), v.a);
        }

        // `input` and `output` are each a black and a white level.
        [[stitchable]] float4 filterLevels(sample_t sample, float2 input, float2 output, float linear) {
            float4 v = unpremultiply(sample);
            float3 level = (formToEncoded(v.rgb, linear) - input.x) / (input.y - input.x);

            return filterFinish(formFromEncoded(output.x + level * (output.y - output.x), linear), v.a);
        }

        // `table` holds the entries of a `size` cube as `size` columns of red by `size` x `size` rows of green plus
        // blue times `size`, at texel centres. The image's colours are looked up on the encoded form, clipped to the
        // domain, and the result is mixed with them by `amount` in their own form. An image already converted to a
        // LUT's space is taken as it is at a `linear` of 0.
        [[stitchable]] float4 filterLookUp(
            sampler image,
            sampler table,
            float size,
            float3 domainMin,
            float3 domainMax,
            float amount,
            float linear,
            destination dest
        ) {
            float4 v = unpremultiply(image.sample(image.transform(dest.coord())));
            float3 encoded = formToEncoded(v.rgb, linear);
            float3 index = clamp((encoded - domainMin) / (domainMax - domainMin), 0.0, 1.0) * (size - 1.0);
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

            return filterFinish(mix(v.rgb, formFromEncoded(mapped, linear), amount), v.a);
        }

        // `filtered` is an entry's result for `sample`, both premultiplied.
        [[stitchable]] float4 filterMix(sample_t sample, sample_t filtered, float mix) {
            return sample + (filtered - sample) * mix;
        }

        // `blurred` is the Gaussian blur of `sample`'s image, both premultiplied.
        [[stitchable]] float4 filterSharpen(sample_t sample, sample_t blurred, float amount) {
            return filterClampedAlpha(sample + amount * (sample - blurred));
        }

        // The pixel weighed by smoothstep(0.5, 1, L), L its luma clamped to 0 to 1.
        [[stitchable]] float4 filterBloomBright(sample_t sample, float linear) {
            float luma = clamp(formLuma(unpremultiply(sample).rgb, linear), 0.0, 1.0);

            return sample * smoothstep(0.5, 1.0, luma);
        }

        // `glow` is the blur of the bright parts, and `tint` the bloom's colour in the samples' form premultiplied, or
        // white.
        [[stitchable]] float4 filterBloomAdd(sample_t sample, sample_t glow, float amount, float4 tint) {
            return filterClampedAlpha(sample + amount * glow * tint);
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
            float reach = length(dest.coord() - centre) / halfDiagonal;
            float falloff = radius < 1.0 ? smoothstep(radius, 1.0, reach) : step(1.0, reach);

            return float4(sample.rgb * (1.0 - amount * falloff), sample.a);
        }

        // Grains are squares `size` across on a grid from `topLeft`, the extent's top left corner. `seed` is the
        // seed's low and high sixteen bits. The noise is weighed by the luma clamped to 0 to 1.
        [[stitchable]] float4 filterGrain(
            sample_t sample,
            float amount,
            float size,
            float2 topLeft,
            float2 seed,
            float linear,
            destination dest
        ) {
            float4 v = unpremultiply(sample);
            float3 encoded = formToEncoded(v.rgb, linear);
            float2 place = float2(dest.coord().x - topLeft.x, topLeft.y - dest.coord().y);
            float noise = filterNoise(int2(floor(place / size)), uint(seed.x) | (uint(seed.y) << 16));
            float luma = clamp(dot(encoded, float3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);

            return filterFinish(formFromEncoded(encoded + amount * 4.0 * luma * (1.0 - luma) * noise, linear), v.a);
        }

        // The premultiplied value of `map`'s pixel at (column, row), rows counted from the top, read at its centre and
        // clamped to 0 to 1.
        static inline float4 filterMapPixel(sampler map, float2 pixel, float2 size) {
            return clamp(map.sample(map.transform(float2(pixel.x + 0.5, size.y - pixel.y - 0.5))), 0.0, 1.0);
        }

        // The premultiplied value of `image`'s pixel at (column, row) of `extent`, rows counted from the bottom, the
        // edge pixels extended outward, read at its centre.
        static inline float4 filterImagePixel(sampler image, float2 pixel, float4 extent) {
            float2 inside = clamp(pixel, float2(0.0), extent.zw - 1.0);

            return image.sample(image.transform(extent.xy + inside + 0.5));
        }

        // `map`, `mapSize` pixels, is laid over `box`, its left, top, width and height in the image's coordinates, moved
        // by `offset` and repeated beyond its edges, and m is its red and green bilinear between its pixels' centres,
        // the pixels across an edge being those of its other side. The pixel reads `image`, whose extent is `extent`,
        // `amount` × (2m - 1) away, bilinear between its pixels' centres. `offset` and the move have y pointing down,
        // as the box does, and both samplers read the nearest pixel, so the kernel interpolates in 32-bit floats.
        [[stitchable]] float4 filterDisplace(
            sampler image,
            sampler map,
            float2 mapSize,
            float4 box,
            float2 offset,
            float amount,
            float4 extent,
            destination dest
        ) {
            float2 coord = dest.coord();
            float2 place = float2(coord.x - box.x, box.y - coord.y) - offset;
            float2 texel = fract(place / box.zw) * mapSize - 0.5;
            float2 lower = floor(texel);
            float2 fraction = texel - lower;
            float2 first = select(lower, lower + mapSize, lower < 0.0);
            float2 second = select(first + 1.0, float2(0.0), first + 1.0 >= mapSize);
            float2 m = mix(
                mix(
                    filterMapPixel(map, first, mapSize),
                    filterMapPixel(map, float2(second.x, first.y), mapSize),
                    fraction.x
                ),
                mix(
                    filterMapPixel(map, float2(first.x, second.y), mapSize),
                    filterMapPixel(map, second, mapSize),
                    fraction.x
                ),
                fraction.y
            ).rg;
            float2 move = amount * (2.0 * m - 1.0);
            float2 point = coord + float2(move.x, -move.y) - extent.xy - 0.5;
            float2 low = floor(point);
            float2 weight = point - low;
            float4 value = mix(
                mix(
                    filterImagePixel(image, low, extent),
                    filterImagePixel(image, low + float2(1.0, 0.0), extent),
                    weight.x
                ),
                mix(
                    filterImagePixel(image, low + float2(0.0, 1.0), extent),
                    filterImagePixel(image, low + 1.0, extent),
                    weight.x
                ),
                weight.y
            );

            return filterClampedAlpha(value);
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
