//
//  MTLTextureProducer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/11.
//

#if canImport(Metal)
import Metal
import CoreMedia
import ReplayKit

internal final class MTLTextureProducer: NSObject, MediaSampleProducer {
    
    fileprivate var running: Bool = false
    fileprivate let textureSize: CGSize
    
    fileprivate let device: MTLDevice
    fileprivate let commandQueue: MTLCommandQueue
    fileprivate var render: VideoPixelBufferRender?
    
    fileprivate var semaphore: DispatchSemaphore
    fileprivate var queue: DispatchQueue
    
    var isRunning: Bool {
        return running
    }
    
    var producerType: ProducerType {
        return .video
    }
    
    let sampleConsumers = SampleConsumerContainer()
    
    init(device: MTLDevice, textureSize: CGSize) {
        self.device = device
        self.textureSize = textureSize
        self.commandQueue = device.makeCommandQueue()!
        
        self.semaphore = DispatchSemaphore(value: 1)
        let highQueue = DispatchQueue.global(qos: .userInteractive)
        self.queue = DispatchQueue(label: "MTLTextureProducer.Queue", attributes: [], target: highQueue)
    }
    
    func startRunning() throws {
        guard !running else { return }
        running = true
        
        render = try VideoPixelBufferRender(device:device, textureSize: textureSize)
    }
    
    func stopRunning() {
        guard running else { return }
        running = false
        render = nil
    }
    
    func recommendedSettingsForFileType(_ fileType: MovieFileType) -> [String : Any]? {
        return nil
    }
    
    func renderTexture(_ texture: MTLTexture, atTime time: TimeInterval) {
        guard running else { return }
        
        semaphore.wait()
        
        var res: (CVPixelBuffer, MTLTexture)? = nil
        do {
            res = try render?.newRenderTexture()
        } catch {
            stopRunning()
            notifyConsumersWhenProducerOccursError(error)
            semaphore.signal()
            return
        }
        
        if res == nil {
            // Pixel buffer pool is out of buffers, dropping frame.
            semaphore.signal()
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        commandBuffer.addCompletedHandler { [weak self] (_) in
            defer { self?.semaphore.signal() }
            guard let strongSelf = self else { return }
            let timestamp = CMTime(seconds: time, preferredTimescale: 1000)
            strongSelf.queue.async { [weak self] in
                self?.notifyConsumersWhenMediaSampleReady(.videoPixelBuffer(res!.0, timestamp))
            }
        }
        
        if Int(textureSize.width) == texture.width && Int(textureSize.height) == texture.height {
            render?.copyTextureByBlitEncoder(sourceTexture: texture, targetTexture: res!.1, commandBuffer: commandBuffer)
        } else {
           render?.copyTextureByRenderEncoder(sourceTexture: texture, targetTexture: res!.1, commandBuffer: commandBuffer)
        }
        
        commandBuffer.commit()
    }
}

#endif

