//
//  BlendKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

// The Metal functions of the blend mode kernels, each taking the premultiplied source and backdrop samples.
enum BlendKernelSource {
    static let text = """
        [[stitchable]] float4 blendNormalPlaceholder(sample_t source, sample_t backdrop) {
            return source + backdrop * (1.0 - source.a);
        }
        """
}
