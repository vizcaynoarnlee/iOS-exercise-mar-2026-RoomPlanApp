//
//  PyramidBlend.metal
//  RoomPlanApp
//
//  Metal shaders for multi-band pyramid blending
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Gaussian Downsampling

/// 5x5 Gaussian kernel weights
constant float gaussianKernel[25] = {
    1/256.0,  4/256.0,  6/256.0,  4/256.0, 1/256.0,
    4/256.0, 16/256.0, 24/256.0, 16/256.0, 4/256.0,
    6/256.0, 24/256.0, 36/256.0, 24/256.0, 6/256.0,
    4/256.0, 16/256.0, 24/256.0, 16/256.0, 4/256.0,
    1/256.0,  4/256.0,  6/256.0,  4/256.0, 1/256.0
};

/// Gaussian downsample: blur with 5x5 kernel and sample every other pixel
kernel void gaussianDownsample(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Output texture is half size of input
    // Each output pixel samples a 5x5 region in input

    uint2 inSize = uint2(inTexture.get_width(), inTexture.get_height());
    uint2 outSize = uint2(outTexture.get_width(), outTexture.get_height());

    if (gid.x >= outSize.x || gid.y >= outSize.y) {
        return;
    }

    // Center position in input texture (2x scale)
    uint2 inCenter = gid * 2;

    // Accumulate weighted samples
    float4 sum = float4(0.0);

    for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
            int2 samplePos = int2(inCenter) + int2(dx, dy);

            // Clamp to texture bounds
            samplePos.x = clamp(samplePos.x, 0, int(inSize.x - 1));
            samplePos.y = clamp(samplePos.y, 0, int(inSize.y - 1));

            int kernelIdx = (dy + 2) * 5 + (dx + 2);
            float weight = gaussianKernel[kernelIdx];

            float4 sample = inTexture.read(uint2(samplePos));
            sum += sample * weight;
        }
    }

    outTexture.write(sum, gid);
}

// MARK: - Laplacian Pyramid

/// Bilinear upsample (2x)
kernel void upsample(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint2 outSize = uint2(outTexture.get_width(), outTexture.get_height());

    if (gid.x >= outSize.x || gid.y >= outSize.y) {
        return;
    }

    // Map to input coordinates (half size)
    float2 inCoord = float2(gid) * 0.5;
    uint2 inPos = uint2(floor(inCoord));
    float2 frac = inCoord - float2(inPos);

    // Bilinear interpolation
    uint2 inSize = uint2(inTexture.get_width(), inTexture.get_height());

    uint2 p00 = inPos;
    uint2 p10 = uint2(min(inPos.x + 1, inSize.x - 1), inPos.y);
    uint2 p01 = uint2(inPos.x, min(inPos.y + 1, inSize.y - 1));
    uint2 p11 = uint2(min(inPos.x + 1, inSize.x - 1), min(inPos.y + 1, inSize.y - 1));

    float4 c00 = inTexture.read(p00);
    float4 c10 = inTexture.read(p10);
    float4 c01 = inTexture.read(p01);
    float4 c11 = inTexture.read(p11);

    float4 c0 = mix(c00, c10, frac.x);
    float4 c1 = mix(c01, c11, frac.x);
    float4 result = mix(c0, c1, frac.y);

    outTexture.write(result, gid);
}

/// Compute Laplacian: original - upsampled(blurred)
kernel void computeLaplacian(
    texture2d<float, access::read> original [[texture(0)]],
    texture2d<float, access::read> blurred [[texture(1)]],
    texture2d<float, access::write> laplacian [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint2 size = uint2(original.get_width(), original.get_height());

    if (gid.x >= size.x || gid.y >= size.y) {
        return;
    }

    float4 origPixel = original.read(gid);
    float4 blurPixel = blurred.read(gid);

    // Laplacian = high frequency detail
    float4 laplacianPixel = origPixel - blurPixel;

    laplacian.write(laplacianPixel, gid);
}

// MARK: - Multi-Band Blending

/// Blend two images using mask
kernel void pyramidBlend(
    texture2d<float, access::read> pyramid1 [[texture(0)]],
    texture2d<float, access::read> pyramid2 [[texture(1)]],
    texture2d<float, access::read> mask [[texture(2)]],
    texture2d<float, access::write> blended [[texture(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint2 size = uint2(pyramid1.get_width(), pyramid1.get_height());

    if (gid.x >= size.x || gid.y >= size.y) {
        return;
    }

    float4 pixel1 = pyramid1.read(gid);
    float4 pixel2 = pyramid2.read(gid);

    // Read mask (grayscale: 0 = image1, 1 = image2)
    float maskValue = mask.read(gid).r;

    // Linear blend
    float4 result = mix(pixel1, pixel2, maskValue);

    blended.write(result, gid);
}

// MARK: - Pyramid Reconstruction

/// Add two pyramid levels (for reconstruction)
kernel void addPyramidLevels(
    texture2d<float, access::read> laplacian [[texture(0)]],
    texture2d<float, access::read> lowFreq [[texture(1)]],
    texture2d<float, access::write> result [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint2 size = uint2(result.get_width(), result.get_height());

    if (gid.x >= size.x || gid.y >= size.y) {
        return;
    }

    float4 lap = laplacian.read(gid);
    float4 low = lowFreq.read(gid);

    // Reconstruct: add high frequency detail back to low frequency
    float4 reconstructed = lap + low;

    result.write(reconstructed, gid);
}

// MARK: - Distance Field Mask

/// Create smooth distance field mask from seam line
kernel void createDistanceFieldMask(
    texture2d<float, access::write> mask [[texture(0)]],
    constant float2 &seamLine [[buffer(0)]],
    constant float2 &seamDirection [[buffer(1)]],
    constant float &featherDistance [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint2 size = uint2(mask.get_width(), mask.get_height());

    if (gid.x >= size.x || gid.y >= size.y) {
        return;
    }

    // Calculate distance from seam line
    float2 pos = float2(gid);
    float2 toPoint = pos - seamLine;

    // Project onto seam direction to get signed distance
    float distance = dot(toPoint, seamDirection);

    // Create smooth transition using smoothstep
    float maskValue = smoothstep(-featherDistance, featherDistance, distance);

    mask.write(float4(maskValue, maskValue, maskValue, 1.0), gid);
}
