//
//  ResampleKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/25/26.
//

// The Metal function that resamples a picture of pixels (FRAMES-21 Rules), on premultiplied samples in either form,
// which it only averages. `pictureResample` carries each output pixel back through the inverse map, rows `rowU` and
// `rowV` from the output's point to the source's, and gives it the mean of the source over the box `footprint` wide and
// high centred on the image of its centre, each source pixel a square of its value, read with its edge pixels extended
// outward, the weight of each pixel the length of its square inside the box along each axis. It multiplies that mean by
// the area of the output pixel whose image lies inside `cover`, the rectangle of the source's coordinates the picture
// shows, minimum x and y then maximum x and y, found by cutting the pixel's image, a parallelogram, to that rectangle.
// Points are taken relative to the image of the pixel's centre, so a large source keeps the precision of its edges.
enum ResampleKernelSource {
    static let text = """
        // Cuts the convex polygon `points`, `count` corners, to the side of the line `axis` = `limit` that `sign` names, 1
        // for at least and -1 for at most, writing it to `cut` and giving its number of corners.
        static inline int pictureResampleCut(
            thread const float2 *points,
            int count,
            thread float2 *cut,
            int axis,
            float sign,
            float limit
        ) {
            int kept = 0;
            for (int index = 0; index < count; index++) {
                float2 from = points[index];
                float2 to = points[(index + 1) % count];
                float depthFrom = sign * (from[axis] - limit);
                float depthTo = sign * (to[axis] - limit);
                if (depthFrom >= 0.0) {
                    cut[kept] = from;
                    kept += 1;
                }
                if ((depthFrom >= 0.0) != (depthTo >= 0.0)) {
                    cut[kept] = from + (to - from) * (depthFrom / (depthFrom - depthTo));
                    kept += 1;
                }
            }
            return kept;
        }

        // The share of the output pixel whose image, the parallelogram of the half steps `stepX` and `stepY` about the
        // origin, lies inside `limits`, the cover relative to that origin.
        static inline float pictureResampleCoverage(float2 stepX, float2 stepY, float4 limits) {
            float2 reach = abs(stepX) + abs(stepY);
            if (all(limits.xy <= -reach) && all(reach <= limits.zw)) {
                return 1.0;
            }
            if (any(reach <= limits.xy) || any(limits.zw <= -reach)) {
                return 0.0;
            }
            float2 first[8];
            float2 second[8];
            first[0] = -stepX - stepY;
            first[1] = stepX - stepY;
            first[2] = stepX + stepY;
            first[3] = -stepX + stepY;
            int count = 4;
            count = pictureResampleCut(first, count, second, 0, 1.0, limits.x);
            count = pictureResampleCut(second, count, first, 1, 1.0, limits.y);
            count = pictureResampleCut(first, count, second, 0, -1.0, limits.z);
            count = pictureResampleCut(second, count, first, 1, -1.0, limits.w);
            float twice = 0.0;
            for (int index = 0; index < count; index++) {
                float2 from = first[index];
                float2 to = first[(index + 1) % count];
                twice += from.x * to.y - to.x * from.y;
            }
            float whole = 4.0 * abs(stepX.x * stepY.y - stepX.y * stepY.x);
            return clamp(0.5 * abs(twice) / whole, 0.0, 1.0);
        }

        [[stitchable]] float4 pictureResample(
            sampler source,
            float3 rowU,
            float3 rowV,
            float2 footprint,
            float4 cover,
            destination dest
        ) {
            float3 point = float3(dest.coord(), 1.0);
            float2 centre = float2(dot(rowU, point), dot(rowV, point));
            float2 stepX = 0.5 * float2(rowU.x, rowV.x);
            float2 stepY = 0.5 * float2(rowU.y, rowV.y);
            float coverage = pictureResampleCoverage(stepX, stepY, cover - float4(centre, centre));
            if (coverage <= 0.0) {
                return float4(0.0);
            }

            float2 low = centre - 0.5 * footprint;
            float2 high = centre + 0.5 * footprint;
            int2 first = int2(floor(low));
            int2 last = int2(ceil(high)) - 1;
            float4 sum = float4(0.0);
            float rows = 0.0;
            float columns = 0.0;
            for (int column = first.x; column <= last.x; column++) {
                columns += max(min(high.x, float(column + 1)) - max(low.x, float(column)), 0.0);
            }
            for (int row = first.y; row <= last.y; row++) {
                float weightY = min(high.y, float(row + 1)) - max(low.y, float(row));
                if (weightY <= 0.0) {
                    continue;
                }
                float4 line = float4(0.0);
                for (int column = first.x; column <= last.x; column++) {
                    float weightX = min(high.x, float(column + 1)) - max(low.x, float(column));
                    if (weightX <= 0.0) {
                        continue;
                    }
                    line += weightX * source.sample(source.transform(float2(float(column) + 0.5, float(row) + 0.5)));
                }
                sum += weightY * line;
                rows += weightY;
            }
            return sum * (coverage / (rows * columns));
        }
        """
}
