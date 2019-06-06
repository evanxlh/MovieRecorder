//
//  SCNViewVideoSource.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/28.
//

import CoreMedia
import CoreVideo
import SceneKit

public class SCNViewVideoSource: NSObject, SampleSource {
    
    enum Error: Swift.Error {
        case failToPrepareMetalRender
    }
    
    fileprivate var running: Bool = false
    
    fileprivate weak var scnView: SCNView!
    fileprivate var scnViewOriginDelegate: SCNSceneRendererDelegate?
    
    fileprivate var textureLoader: PixelBufferTextureLoader
    fileprivate var bufferPool: PixelBufferPool?
    fileprivate var renderBuffer: CVPixelBuffer?
    fileprivate var videoRender: SCNRenderer?
    
    fileprivate var renderTexture: MTLTexture?
    
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
    
    //MARK: - Public Properties
    
    public var isRunning: Bool {
        return running
    }
    
    public var sourceType: SampleSourceType {
        return .video
    }
    
    public let sampleConsumers = SampleConsumerContainer()
    
    //MARK: - Public APIs
    
    public init(scnView: SCNView, videoSize: CGSize, videoFramerate: Int) {
        self.scnView = scnView
        self.videoSize = videoSize
        self.videoFramerate = videoFramerate
        self.semaphore = DispatchSemaphore(value: 1)
        self.textureLoader = PixelBufferTextureLoader(device: scnView.device!)
        
        var scnViewFramerate = scnView.preferredFramesPerSecond
        if scnViewFramerate == 0 {
            scnViewFramerate = 60
        }
        frameInterval = max(1, scnViewFramerate / videoFramerate)
    }
    
    public func startRunning() throws {
        guard !isRunning else { return }
        
        running = true
        currentFrameIndex = 0
        takeoverRenderDelegate()
        try prepareMetalRender()
    }
    
    public func stopRunning() {
        guard isRunning else { return }
        running = false
        giveBackRenderDelegate()
        videoRender = nil
        renderBuffer = nil
        renderTexture = nil
        bufferPool = nil
    }

}

//MARK: - Privates

fileprivate extension SCNViewVideoSource {
    
    func prepareMetalRender() throws {
       
        bufferPool = try PixelBufferPool(pixelBufferCount: 6, width: Int(videoSize.width), height: Int(videoSize.height),pixelFormat: kCVPixelFormatType_32BGRA)
        renderBuffer = try bufferPool?.createPixelBuffer()
        
        guard let metalTexture = textureLoader.loadTexture(from: renderBuffer!, usingSRGB: true) else {
            throw Error.failToPrepareMetalRender
        }
    
        renderTexture = metalTexture.bgraTexture
        videoRender = SCNRenderer(device: scnView.device, options: nil)
        videoRender!.scene = scnView.scene
    }
    
    /// Render the scene view content to pixel buffer.
    func renderToPixelBuffer(atTime time: TimeInterval) {
        guard running else { return }
        
        semaphore.wait()
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].texture = renderTexture
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        
        let viewport = CGRect(origin: .zero, size: videoSize)
        let commandBuffer = videoRender?.commandQueue!.makeCommandBuffer()
        videoRender?.scene = scnView.scene
        videoRender?.pointOfView = scnView.pointOfView
        videoRender?.render(atTime: time, viewport: viewport, commandBuffer: commandBuffer!, passDescriptor: renderPass)
        
        commandBuffer?.addCompletedHandler({ [weak self] (_) in
            guard let buffer = self?.renderBuffer else { return }
            self?.outputPixelBuffer(from: buffer, time: time)
            self?.semaphore.signal()
        })
        
        commandBuffer?.commit()
    }
    
    func outputPixelBuffer(from buffer: CVPixelBuffer, time: TimeInterval) {
        
        do {
            let timestamp = CMTime(seconds: time, preferredTimescale: timeScale)
            let pixelBuffer = try self.bufferPool!.createPixelBuffer(from: buffer)
            notifyConsumersWhenMediaSampleReady(.videoPixelBuffer(pixelBuffer, timestamp))
        } catch {
            print("Create pixel buffer failed: \(error)")
        }
    }
}

//MARK: Takeover SCNView's Render Delegate

extension SCNViewVideoSource: SCNSceneRendererDelegate {
    
    fileprivate func takeoverRenderDelegate() {
        scnViewOriginDelegate = scnView.delegate
        scnView.delegate = self
    }
    
    fileprivate func giveBackRenderDelegate() {
        scnView.delegate = scnViewOriginDelegate
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, updateAtTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, didApplyAnimationsAtTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, didSimulatePhysicsAtTime: time)
    }
    
    @available(iOS 11.0, *)
    public func renderer(_ renderer: SCNSceneRenderer, didApplyConstraintsAtTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, didApplyConstraintsAtTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if currentFrameIndex % frameInterval == 0 {
            renderToPixelBuffer(atTime: time)
        }
        currentFrameIndex += 1
        scnViewOriginDelegate?.renderer?(renderer, willRenderScene: scene, atTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, didRenderScene: scene, atTime: time)
    }
}
