//
//  PixelBufferTextureLoader.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/5.
//

#if !targetEnvironment(simulator)
import Metal
import CoreVideo
import simd

/**
 A composed metal textures created from CVPixelBuffer.
 */
public enum MetalTexture {
    case bgra(MTLTexture)
    case yuv(YUVTexture)
    
    public var isYUV: Bool {
        return yuvTexture != nil
    }
    
    public var isBGRA: Bool {
        return bgraTexture != nil
    }
    
    public var bgraTexture: MTLTexture? {
        switch self {
        case .bgra(let texture):
            return texture
        default:
            return nil
        }
    }
    
    public var yuvTexture: YUVTexture? {
        switch self {
        case .yuv(let texture):
            return texture
        default:
            return nil
        }
    }
}

/**
 YUV colors are represented with one **luminance** component called Y (equivalent to grey scale),
 and two **chrominance** components, called U (blue projection) and V (red projection) respectively.
 
 For more introduction for yuv, see [YUV Definitions](https://wiki.videolan.org/YUV) and
 [YUV Conversion from RGB](https://en.wikipedia.org/wiki/YUV)
 */
public class YUVTexture {
    public let y: MTLTexture
    public let uv: MTLTexture
    public let conversion: YUVToRGBConversion
    
    public init(y: MTLTexture, uv: MTLTexture, conversion: YUVToRGBConversion) {
        self.y = y
        self.uv = uv
        self.conversion = conversion
    }
}

/**
 A wrapper of the conversion matrix and offset for converting yuv to rgb.
 */
public struct YUVToRGBConversion: Equatable {
    public let matrix: float3x3
    public let offset: float3
    
    private static let matrix601 = matrix_float3x3(
        float3(1.164,  1.164, 1.164),
        float3(0.0,   -0.392, 2.017),
        float3(1.596, -0.813,   0.0)
    )
    
    private static let matrix601FullRange = matrix_float3x3(
        float3(1.000,  1.000, 1.000),
        float3(0.000, -0.343, 1.765),
        float3(1.400, -0.711, 0.000)
    )
    
    /// BT.709, which is the standard for HDTV.
    private static let matrix709 = matrix_float3x3(
        float3(1.164,  1.164, 1.164),
        float3(  0.0, -0.213, 2.112),
        float3(1.793, -0.533,   0.0)
    )
    
    public static let k601 = YUVToRGBConversion(matrix: matrix601, offset: float3(-(16.0/255.0), -0.5, -0.5))
    public static let k601FullRange = YUVToRGBConversion(matrix: matrix601FullRange, offset: float3(0.0, -0.5, -0.5))
    public static let k709 = YUVToRGBConversion(matrix: matrix709, offset: float3(-(16.0/255.0), -0.5, -0.5))
    
    public init(matrix: float3x3, offset: float3) {
        self.matrix = matrix
        self.offset = offset
    }
    
    public static func == (lhs: YUVToRGBConversion, rhs: YUVToRGBConversion) -> Bool {
        return lhs.matrix == rhs.matrix && lhs.offset == rhs.offset
    }
    
    public static func != (lhs: YUVToRGBConversion, rhs: YUVToRGBConversion) -> Bool {
        return lhs.matrix != rhs.matrix || lhs.offset != rhs.offset
    }
}

/**
 Load textures from CVPixelBuffer using `CVMetalTextureCache`.
 
 At present, `MetalTextureLoader` only supports the pixel buffer which format is `kCVPixelFormatType_32BGRA`,
 or `kCVPixelFormatType_420YpCbCr8BiPlanarFullRange`, or `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`.
 */
public final class PixelBufferTextureLoader {
    
    fileprivate let device: MTLDevice
    fileprivate var textureCache: CVMetalTextureCache
    
    public init(device: MTLDevice, textureCache: CVMetalTextureCache? = nil) {
        self.device = device
        if let cache = textureCache {
            self.textureCache = cache
            return
        }
        
        var cache: CVMetalTextureCache? = nil
        let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        guard result == kCVReturnSuccess else {
            print("Create texture cache failed: \(result)")
            fatalError()
        }
        
        self.textureCache = cache!
    }
    
    public func loadTexture(from pixelBuffer: CVPixelBuffer, usingSRGB: Bool = true) -> MetalTexture? {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        switch pixelFormat {
        case kCVPixelFormatType_32BGRA:
            if let texture = fetchTexture_bgra(from: pixelBuffer, usingSRGB: usingSRGB) {
                return .bgra(texture)
            }
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            let isFullRange = pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            if let texture = fetchTexture_yuv(from: pixelBuffer, usingSRGB: usingSRGB, isFullRange: isFullRange) {
                return .yuv(texture)
            }
        default:
            break
        }
        
        return nil
    }
    
    public func flush() {
        CVMetalTextureCacheFlush(textureCache, 0)
    }
}

fileprivate extension PixelBufferTextureLoader {
    
    func fetchTexture_bgra(from pixelBuffer: CVPixelBuffer, usingSRGB: Bool) -> MTLTexture? {
        
        var pixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
        if !usingSRGB { pixelFormat = .bgra8Unorm }
        
        return fetchTexture(from: pixelBuffer, planeIndex: 0, pixelFormat: pixelFormat)
    }
    
    func fetchTexture_yuv(from pixelBuffer: CVPixelBuffer, usingSRGB: Bool, isFullRange: Bool) -> YUVTexture? {
        
        var yPixelFormat: MTLPixelFormat = .r8Unorm_srgb
        var uvPixelFormat: MTLPixelFormat = .rg8Unorm_srgb
        if !usingSRGB {
            yPixelFormat = .r8Unorm
            uvPixelFormat = .rg8Unorm
        }
        
        guard let yTexture = fetchTexture(from: pixelBuffer, planeIndex: 0, pixelFormat: yPixelFormat) else {
            return nil
        }
        
        guard let uvTexture = fetchTexture(from: pixelBuffer, planeIndex: 1, pixelFormat: uvPixelFormat) else {
            return nil
        }
        
        let conversion = fetchYUVToRGBConversion(from: pixelBuffer, isFullRange: isFullRange)
        return YUVTexture(y: yTexture, uv: uvTexture, conversion: conversion)
    }
    
    func fetchTexture(from pixelBuffer: CVPixelBuffer, planeIndex: Int, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        let textureAttrs = [kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary
        
        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer,
                                                               textureAttrs, pixelFormat, width, height, planeIndex, &cvTexture)
        guard result == kCVReturnSuccess else {
            print("Create CVMetalTexture at plane \(planeIndex) failed: \(result)")
            return nil
        }
        
        guard let texture = CVMetalTextureGetTexture(cvTexture!) else {
            print("Get texture from CVMetalTexture failed")
            return nil
        }
        return texture
    }
    
    func fetchYUVToRGBConversion(from pixelBuffer: CVPixelBuffer, isFullRange: Bool) -> YUVToRGBConversion {
        
        var conversion: YUVToRGBConversion = isFullRange ? .k601FullRange : .k601
        
        // ColorAttachment must takeUnretainedValue, or will crash later by dispatch_release.(Test on the iOS 12)
        if let colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, nil)?.takeUnretainedValue() {
            if CFStringCompare((colorAttachments as! CFString), kCVImageBufferYCbCrMatrix_ITU_R_601_4, .compareCaseInsensitive) != .compareEqualTo {
                conversion = .k709
            }
        }
        
        return conversion
    }
}

#endif
