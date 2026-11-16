//
//  FilterKernelSource.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

// The Metal functions of the filter operation kernels.
enum FilterKernelSource {
    static let text = """
        [[stitchable]] float4 filterIdentityPlaceholder(sample_t sample) {
            return sample;
        }
        """
}
