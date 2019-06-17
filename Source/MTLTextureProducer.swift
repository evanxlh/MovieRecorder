//
//  MTLTextureProducer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/11.
//

#if !targetEnvironment(simulator)
import Metal
import CoreMedia
import ReplayKit

internal final class MTLTextureProducer: NSObject, VideoSampleProducer {
    
    fileprivate var running: Bool = false
    fileprivate let device: MTLDevice
    fileprivate let commandQueue: MTLCommandQueue
    fileprivate var render: VideoPixelBufferRender?
    fileprivate var queue: DispatchQueue
    
    private(set) var videoResolution: CGSize
    private(set) var videoFramerate: Int
    
    var isRunning: Bool {
        return running
    }
    
    var producerType: ProducerType {
        return .video
    }
    
    let sampleConsumers = SampleConsumerContainer()
    
    init(device: MTLDevice, textureSize: CGSize, framerate: Int) {
        self.device = device
        self.videoFramerate = framerate
        self.videoResolution = textureSize
        self.commandQueue = device.makeCommandQueue()!

        let highQueue = DispatchQueue.global(qos: .userInteractive)
        self.queue = DispatchQueue(label: "MTLTextureProducer.Queue", attributes: [], target: highQueue)
    }
    
    func startRunning() throws {
        guard !running else { return }
        running = true
        
        render = try VideoPixelBufferRender(device:device, textureSize: videoResolution)
    }
    
    func stopRunning() {
        guard running else { return }
        running = false
        render = nil
    }
    
    func renderTexture(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer, atTime time: TimeInterval) {
        guard running else { return }
    
        var res: (CVPixelBuffer, MTLTexture)? = nil
        do {
            res = try render?.newRenderTexture()
        } catch {
            stopRunning()
            notifyConsumersWhenProducerOccursError(error)
            return
        }
        
        if res == nil {
            // Pixel buffer pool is out of buffers, dropping frame.
            return
        }
        
        commandBuffer.addCompletedHandler { [weak self] (_) in
            guard let strongSelf = self else { return }
            let timestamp = CMTime(seconds: time, preferredTimescale: 1000)
            strongSelf.queue.async { [weak self] in
                self?.notifyConsumersWhenMediaSampleReady(.videoPixelBuffer(res!.0, timestamp))
            }
        }
        
        if Int(videoResolution.width) == texture.width && Int(videoResolution.height) == texture.height {
            render?.copyTextureByBlitEncoder(sourceTexture: texture, targetTexture: res!.1, commandBuffer: commandBuffer)
        } else {
           render?.copyTextureByRenderEncoder(sourceTexture: texture, targetTexture: res!.1, commandBuffer: commandBuffer)
        }
    }
}

#endif

