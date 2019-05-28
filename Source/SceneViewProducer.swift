//
//  SceneViewBufferProducer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/28.
//

import CoreMedia
import CoreVideo
import SceneKit

internal class SceneViewProducer: BufferProducer {
    
    fileprivate var scnView: SCNView
    fileprivate var videoRender: SCNRenderer
    fileprivate let videoSize: CGSize
    
    fileprivate var bufferPool: PixelBufferPool
    fileprivate var renderBuffer: CVPixelBuffer
    
    fileprivate var textureCache: CVMetalTextureCache?
    fileprivate var renderTexture: MTLTexture
    
    var delegate: BufferProducerDelegate?
    var queue: DispatchQueue
    
    var timeScale: TimeScale
    
    fileprivate lazy var renderPass: MTLRenderPassDescriptor = {
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = renderTexture
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        return renderPass
    }()
    
    init(scnView: SCNView, videoSize: CGSize, timeScale: TimeScale,  delegate: BufferProducerDelegate? = nil) throws {
        self.scnView = scnView
        self.timeScale = timeScale
        self.videoSize = videoSize
        self.videoRender = SCNRenderer(device: scnView.device, options: nil)
        self.videoRender.scene = scnView.scene
        self.queue = DispatchQueue(label: "SceneViewProducer.DelegateQueue")
        
        var result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, scnView.device!, nil, &textureCache)
        guard result == kCVReturnSuccess else {
            fatalError("Create texture cache failed: \(result)")
        }
        
        bufferPool = try PixelBufferPool(pixelBufferCount: 6, width: Int(videoSize.width), height: Int(videoSize.height),
                                         pixelFormat: kCVPixelFormatType_32RGBA)
        renderBuffer = try bufferPool.createPixelBuffer()
        
        let textureAttributes = [kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary
        var metalTexture: CVMetalTexture?
        result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, renderBuffer,
                     textureAttributes, .bgra8Unorm_srgb, bufferPool.width, bufferPool.height, 0, &metalTexture)
        guard result == kCVReturnSuccess else {
            throw CoreVideoError.failure(CVReturnValue(result))
        }
        guard let texture = CVMetalTextureGetTexture(metalTexture!) else {
            fatalError("Get texture failed")
        }
        self.renderTexture = texture
    }
    
    func start() {
    
    }
    
    func stop() {
        
    }
    
    /**
     Render the scene view content to pixel buffer.
     If succeeds, delegate function `bufferProducer(_ producer: BufferProducer, didOutput buffer: Buffer)` will be invoked.
     */
    func renderToPixelBuffer(atTime time: TimeInterval) {
        let viewport = CGRect(origin: .zero, size: videoSize)
        let commandBuffer = videoRender.commandQueue?.makeCommandBuffer()
        videoRender.render(atTime: time, viewport: viewport, commandBuffer: commandBuffer!, passDescriptor: renderPass)
        videoRender.scene = scnView.scene
        videoRender.pointOfView = scnView.pointOfView
        
        commandBuffer!.addCompletedHandler({ (_) in
            guard self.delegate != nil else { return }
            
            do {
                let pixelBuffer = try self.bufferPool.createPixelBuffer(from: self.renderBuffer)
                let timestamp = CMTime(seconds: time, preferredTimescale: self.timeScale.rawValue)
                self.queue.async {
                    self.delegate?.bufferProducer(self, didOutput: .videoPixelBuffer(pixelBuffer, timestamp))
                }
            } catch {
                print("Create pixel buffer failed: \(error)")
            }
        })
        commandBuffer!.commit()
    }
    
}
