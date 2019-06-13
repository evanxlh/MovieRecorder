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
    
    fileprivate var running: Bool = false
    fileprivate var queue: DispatchQueue
    fileprivate var semaphore: DispatchSemaphore
    
    fileprivate weak var scnView: SCNView!
    fileprivate var scnViewOriginDelegate: SCNSceneRendererDelegate?
    fileprivate var videoRender: SCNRenderer?
    fileprivate var render: VideoPixelBufferRender?
    
    fileprivate var videoSize: CGSize
    fileprivate var videoFramerate: Int
    
    /// Used to how frequently the video sample produces.
    fileprivate var frameInterval: Int
    
    /// Track how many times which scnView renders.
    fileprivate var currentFrameIndex: Int = 0
    
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
        render = nil
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
        render = try VideoPixelBufferRender(device: scnView.device!, textureSize: videoSize)
        videoRender = SCNRenderer(device: scnView.device, options: nil)
        videoRender!.scene = scnView.scene
    }
    
    /// Render the scene view content to pixel buffer.
    func renderToPixelBuffer(atTime time: TimeInterval) {
        guard running else { return }
        
        semaphore.wait()
        
        var res: (CVPixelBuffer, MTLTexture)? = nil
        let commandBuffer = videoRender!.commandQueue!.makeCommandBuffer()!
        
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
        
        commandBuffer.addCompletedHandler({ [weak self] (_) in
            defer { self?.semaphore.signal() }
            guard let strongSelf = self else { return }
            
            let timestamp = CMTime(seconds: time, preferredTimescale: 1000)
            strongSelf.queue.async { [weak self] in
                self?.notifyConsumersWhenMediaSampleReady(.videoPixelBuffer(res!.0, timestamp))
            }
        })
        
        let renderPass = render!.newRenderPass()
        renderPass.colorAttachments[0].texture = res!.1
        
        let viewport = CGRect(origin: .zero, size: videoSize)
        videoRender?.scene = scnView.scene
        videoRender?.pointOfView = scnView.pointOfView
        videoRender?.render(atTime: time, viewport: viewport, commandBuffer: commandBuffer, passDescriptor: renderPass)
        
        commandBuffer.commit()
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
