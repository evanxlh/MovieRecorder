//
//  VideoPixelBufferRender.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/13.
//

import Metal

internal final class VideoPixelBufferRender {
    
    enum Error: Swift.Error {
        case failToCreateVideoRenderTexture
    }
    
    enum Rotation {
        case noRotation
        case rotateCounterclockwise
        case rotateClockwise
        case rotate180
        case flipHorizontally
        case flipVertically
        case rotateClockwiseAndFlipVertically
        case rotateClockwiseAndFlipHorizontally
        
        func flipsDimensions() -> Bool {
            switch self {
            case .noRotation, .rotate180, .flipHorizontally, .flipVertically: return false
            case .rotateCounterclockwise, .rotateClockwise, .rotateClockwiseAndFlipVertically, .rotateClockwiseAndFlipHorizontally: return true
            }
        }
    }
    
    fileprivate var textureLoader: PixelBufferTextureLoader
    fileprivate var bufferPool: PixelBufferPool
    fileprivate let device: MTLDevice
    
    let imageVertices: [Float] = [-1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0]
    let textureCoords: [Float] = [ 0.0,  0.0, 1.0,  0.0,  0.0, 1.0, 1.0, 1.0]
    let imageVerticesSize: Int = 8 * MemoryLayout<Float>.size
    let textureCoordsSize: Int = 8 * MemoryLayout<Float>.size
    
    fileprivate lazy var library: MTLLibrary = {
        let bundle = Bundle(for: VideoPixelBufferRender.self)
        do {
            return try device.makeDefaultLibrary(bundle: bundle)
        } catch {
            fatalError("Can not create default shader library.")
        }
    }()
    
    lazy private(set) var renderPipeline: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.sampleCount = 1
        descriptor.vertexFunction = library.makeFunction(name: "passthroughVertices")
        descriptor.fragmentFunction = library.makeFunction(name: "renderTexture")
        do {
            let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            return pipeline
        } catch {
            fatalError("Create video render pipeline failed")
        }
    }()
    
    init(device: MTLDevice, textureSize: CGSize) throws {
        self.device = device
        self.textureLoader = PixelBufferTextureLoader(device:device)
        self.bufferPool = try PixelBufferPool(
            pixelBufferCount: 6,
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            pixelFormat: kCVPixelFormatType_32BGRA
        )
    }
    
    func newRenderPass() -> MTLRenderPassDescriptor {
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        return renderPass
    }
    
    /// Create a new render texture backed with pixel buffer.
    func newRenderTexture() throws -> (CVPixelBuffer, MTLTexture)? {
        
        var targetPixelBuffer: CVPixelBuffer? = nil
        do {
            targetPixelBuffer = try bufferPool.createPixelBuffer()
        } catch {
            switch error as! CoreVideoError {
            case .failure(let errCode):
                if errCode.value == kCVReturnWouldExceedAllocationThreshold {
                    // If pixel buffer pool can not allocate more pixel buffers, flushing texture cache,
                    // later we'll try to let pixel buffer pool create one again.
                    textureLoader.flush()
                } else {
                    throw error
                }
            }
        }
        
        if targetPixelBuffer == nil {
            do {
                targetPixelBuffer = try bufferPool.createPixelBuffer()
            } catch {
                switch error as! CoreVideoError {
                case .failure(let errCode):
                    if errCode.value == kCVReturnWouldExceedAllocationThreshold {
                        print("Pixel buffer pool is out of buffers, dropping frame")
                        return nil
                    } else {
                        throw error
                    }
                }
            }
        }
        
        guard let texture = textureLoader.loadTexture(from: targetPixelBuffer!, usingSRGB: true)?.bgraTexture else {
            throw Error.failToCreateVideoRenderTexture
        }
        
        return (targetPixelBuffer!, texture)
    }
    
    /// The size of sourceTexture must be equal with the size of targetTexture.
    func copyTextureByBlitEncoder(sourceTexture: MTLTexture, targetTexture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        let origin = MTLOrigin(x: 0, y: 0, z: 0)
        let size = MTLSize(width: sourceTexture.width, height: sourceTexture.height, depth: 1)
        
        blitEncoder?.copy(
            from: sourceTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: origin,
            sourceSize: size,
            to: targetTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: origin
        )
        
        blitEncoder?.endEncoding()
    }
    
    func copyTextureByRenderEncoder(sourceTexture: MTLTexture, targetTexture: MTLTexture, commandBuffer: MTLCommandBuffer)
    {
        let renderPass = newRenderPass()
        renderPass.colorAttachments[0].texture = targetTexture
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)
        renderEncoder?.setRenderPipelineState(renderPipeline)
        renderEncoder?.setVertexBytes(imageVertices, length: imageVerticesSize, index: 0)
        renderEncoder?.setVertexBytes(textureCoords, length: textureCoordsSize, index: 1)
        renderEncoder?.setFragmentTexture(sourceTexture, index: 0)
        renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 4)
        renderEncoder?.endEncoding()
    }
}

fileprivate extension VideoPixelBufferRender {
    
    func textureCoordinates(for rotation: Rotation) -> [Float] {
        switch rotation {
        case .noRotation:
            return [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0]
        case .rotateCounterclockwise:
            return [0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0]
        case .rotateClockwise:
            return [1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0]
        case .rotate180:
            return [1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0]
        case .flipHorizontally:
            return [1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0]
        case .flipVertically:
            return [0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0]
        case .rotateClockwiseAndFlipVertically:
            return [0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0]
        case .rotateClockwiseAndFlipHorizontally:
            return [1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
        }
    }
}


