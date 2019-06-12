//
//  SCNViewProducer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/28.
//

import CoreMedia
import CoreVideo
import SceneKit
import AVFoundation

internal final class SCNViewProducer: NSObject, MediaSampleProducer {
    
    enum Error: Swift.Error {
        case failToPrepareMetalRender
        case failToRenderVideoBuffer
    }
    
    fileprivate var running: Bool = false
    fileprivate var queue: DispatchQueue
    
    fileprivate weak var scnView: SCNView!
    fileprivate var scnViewOriginDelegate: SCNSceneRendererDelegate?
    
    fileprivate var textureLoader: PixelBufferTextureLoader
    fileprivate var bufferPool: PixelBufferPool?
    fileprivate var videoRender: SCNRenderer?
    
    fileprivate var videoSize: CGSize
    fileprivate var videoFramerate: Int
    
    /// Used to how frequently the video sample produces.
    fileprivate var frameInterval: Int
    
    /// Track how many times which scnView renders.
    fileprivate var currentFrameIndex: Int = 0
    
    /// Record the timestamp which the first sample is produced.
    fileprivate var startTime: TimeInterval? = nil
    fileprivate let timeScale: CMTimeScale = 10000
    fileprivate var semaphore: DispatchSemaphore
    
    //MARK: -  Properties
    
    var isRunning: Bool {
        return running
    }
    
    var producerType: ProducerType {
        return .video
    }
    
    let sampleConsumers = SampleConsumerContainer()
    
    deinit {
        semaphore.signal()
        print("\(self) deinit")
    }
    
    //MARK: -  APIs
    
    init(scnView: SCNView, videoSize: CGSize, videoFramerate: Int) {
        self.scnView = scnView
        self.videoSize = videoSize
        self.videoFramerate = videoFramerate
        self.semaphore = DispatchSemaphore(value: 1)
        self.textureLoader = PixelBufferTextureLoader(device: scnView.device!)
        let highQueue = DispatchQueue.global(qos: .userInteractive)
        self.queue = DispatchQueue(label: "SCNViewProducer.Queue", attributes: [], target: highQueue)
        
        var scnViewFramerate = scnView.preferredFramesPerSecond
        if scnViewFramerate == 0 {
            scnViewFramerate = 60
        }
        frameInterval = max(1, scnViewFramerate / videoFramerate)
    }
    
    func startRunning() throws {
        guard !isRunning else { return }
        
        running = true
        currentFrameIndex = 0
        try prepareMetalRender()
        
        // When metal render prepared, then take over the SCNView render delegate.
        takeoverRenderDelegate()
    }
    
    func stopRunning() {
        guard isRunning else { return }
        running = false
        giveBackRenderDelegate()
        videoRender = nil
        bufferPool = nil
    }
    
    func recommendedSettingsForFileType(_ fileType: MovieFileType) -> [String : Any]? {
        let compressionProperties = [
            AVVideoAverageBitRateKey: Float(videoSize.width * videoSize.height) * 7.2,
            AVVideoExpectedSourceFrameRateKey: videoFramerate,
            AVVideoMaxKeyFrameIntervalKey: videoFramerate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
        ] as [String : Any]
        
        let videoSettings =  [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
            AVVideoCompressionPropertiesKey : compressionProperties
        ] as [String: Any]
        
        return videoSettings
    }
}

//MARK: - Privates

fileprivate extension SCNViewProducer {
    
    func prepareMetalRender() throws {
       
        bufferPool = try PixelBufferPool(pixelBufferCount: 6, width: Int(videoSize.width), height: Int(videoSize.height), pixelFormat: kCVPixelFormatType_32BGRA)
        videoRender = SCNRenderer(device: scnView.device, options: nil)
        videoRender!.scene = scnView.scene
    }
    
    /// Render the scene view content to pixel buffer.
    func renderToPixelBuffer(atTime time: TimeInterval) {
        guard running else { return }
        
        semaphore.wait()
        guard let commandBuffer = videoRender?.commandQueue?.makeCommandBuffer() else {
            semaphore.signal()
            return
        }
        
        var res: (CVPixelBuffer, MTLTexture)? = nil
        do {
            res = try prepareRenderTexture()
        } catch {
            stopRunning()
            notifyConsumersWhenProducerOccursError(error)
            semaphore.signal()
            return
        }
        
        if res == nil {
            semaphore.signal()
            return
        }
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].texture = res!.1
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        
        let viewport = CGRect(origin: .zero, size: videoSize)
        videoRender?.scene = scnView.scene
        videoRender?.pointOfView = scnView.pointOfView
        videoRender?.render(atTime: time, viewport: viewport, commandBuffer: commandBuffer, passDescriptor: renderPass)
        
        commandBuffer.addCompletedHandler({ [weak self] (_) in
            defer { self?.semaphore.signal() }
            guard let strongSelf = self else { return }
            
            let timestamp = CMTime(seconds: time, preferredTimescale: strongSelf.timeScale)
            strongSelf.queue.async { [weak self] in
                self?.notifyConsumersWhenMediaSampleReady(.videoPixelBuffer(res!.0, timestamp))
            }
        })
        
        commandBuffer.commit()
    }
    
    func outputPixelBuffer(from buffer: CVPixelBuffer, time: TimeInterval) {
        
        do {
            let timestamp = CMTime(seconds: time, preferredTimescale: timeScale)
            let pixelBuffer = try self.bufferPool!.createPixelBuffer(from: buffer)
            queue.async { [weak self] in
                self?.notifyConsumersWhenMediaSampleReady(.videoPixelBuffer(pixelBuffer, timestamp))
            }
        } catch {
            print("Create pixel buffer failed: \(error)")
        }
    }
    
    func prepareRenderTexture() throws -> (CVPixelBuffer, MTLTexture)? {
        
        var targetPixelBuffer: CVPixelBuffer? = nil
        do {
            targetPixelBuffer = try bufferPool!.createPixelBuffer()
        } catch {
            switch error as! CoreVideoError {
            case .failure(let errCode):
                if errCode.value == kCVReturnWouldExceedAllocationThreshold {
                    textureLoader.flush()
                } else {
                    throw error
                }
            }
        }
        
        if targetPixelBuffer == nil {
            do {
                targetPixelBuffer = try bufferPool!.createPixelBuffer()
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
            throw Error.failToRenderVideoBuffer
        }
        
        return (targetPixelBuffer!, texture)
    }
}

//MARK: Takeover SCNView's Render Delegate

extension SCNViewProducer: SCNSceneRendererDelegate {
    
    fileprivate func takeoverRenderDelegate() {
        scnViewOriginDelegate = scnView.delegate
        scnView.delegate = self
    }
    
    fileprivate func giveBackRenderDelegate() {
        scnView.delegate = scnViewOriginDelegate
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, updateAtTime: time)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, didApplyAnimationsAtTime: time)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, didSimulatePhysicsAtTime: time)
    }
    
    @available(iOS 11.0, *)
    func renderer(_ renderer: SCNSceneRenderer, didApplyConstraintsAtTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, didApplyConstraintsAtTime: time)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if currentFrameIndex % frameInterval == 0 {
            renderToPixelBuffer(atTime: time)
        }
        currentFrameIndex += 1
        
        scnViewOriginDelegate?.renderer?(renderer, willRenderScene: scene, atTime: time)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, didRenderScene: scene, atTime: time)
    }
}
