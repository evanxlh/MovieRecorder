//
//  SCNViewTrackDataProvider.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/28.
//

import CoreMedia
import CoreVideo
import SceneKit

public class SCNViewTrackDataProvider: NSObject, MovieTrackDataProvider {
    
    fileprivate var audioSession: AudioCaptureSession?
    fileprivate var running: Bool = false
    fileprivate var queue: DispatchQueue
    
    fileprivate weak var scnView: SCNView!
    fileprivate var scnViewOriginDelegate: SCNSceneRendererDelegate?
    
    fileprivate var bufferPool: PixelBufferPool?
    fileprivate var renderBuffer: CVPixelBuffer?
    fileprivate var videoRender: SCNRenderer?
    
    fileprivate var textureCache: CVMetalTextureCache?
    fileprivate var renderTexture: MTLTexture?
    
    fileprivate var videoSize: CGSize
    fileprivate var videoFramerate: Int
    
    /// Used to how frequently the video track data produces.
    fileprivate var frameInterval: Int
    
    /// Track how many times which scnView renders.
    fileprivate var currentFrameIndex: Int = 0
    
    /// Record the timestamp which the first track data is produced.
    fileprivate var startTime: TimeInterval? = nil
    fileprivate let timeScale: CMTimeScale = 1000
    
    fileprivate lazy var renderPass: MTLRenderPassDescriptor = {
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        return renderPass
    }()
    
    
    //MARK: - Public Properties
    
    public var isRunning: Bool {
        return running
    }
    
    public var trackConfiguration: MovieTrackConfiguration
    
    public var errorHandler: ((MovieTrackDataProviderError) -> Void)?
    
    public var trackDataHandler: ((MovieTrackData) -> Void)?
    
    //MARK: - Public APIs
    
    public init(scnView: SCNView, trackConfiguration: MovieTrackConfiguration) {
        self.scnView = scnView
        self.trackConfiguration = trackConfiguration
        self.videoSize = trackConfiguration.videoSize
        self.videoFramerate = trackConfiguration.videoFramerate
        self.queue = DispatchQueue(label: "SCNViewTrackDataProvider.Queue")
        
        var scnViewFramerate = scnView.preferredFramesPerSecond
        if scnViewFramerate == 0 {
            scnViewFramerate = 60
        }
        frameInterval = max(1, scnViewFramerate / videoFramerate)
    }
    
    public func startRunning(completionBlcok: @escaping (() -> Void)) {
        guard !isRunning else { return }
        queue.async {
            do {
                try self.prepareAndStart()
                self.running = true
                self.takeoverRenderDelegate()
                completionBlcok()
            } catch {
                self.errorHandler?(.failToStart(error))
            }
        }
    }
    
    public func stopRunning(completionBlcok: @escaping (() -> Void)) {
        guard isRunning else { return }
        self.running = false
        queue.async {
            self.giveBackRenderDelegate()
            self.audioSession?.stop()
            self.audioSession = nil
            self.videoRender = nil
            self.renderBuffer = nil
            self.renderTexture = nil
            self.bufferPool = nil
            self.textureCache = nil
        }
    }

}

//MARK: - Privates

fileprivate extension SCNViewTrackDataProvider {
    
    func prepareAndStart() throws {
        
        currentFrameIndex = 0
        
        switch trackConfiguration {
        case .video(let configuration):
            try prepareMetalRender()
        case let .audioAndVideo(audioConfiguration, videoConfiuration):
            try prepareAudioProvider()
            try prepareMetalRender()
        }
    }
    
    func prepareAudioProvider() throws {
        audioSession = AudioCaptureSession(sampleBufferCallbackQueue: queue)
        audioSession!.sampleBufferHandler = { [weak self] (_ sampleBuffer) in
            self?.trackDataHandler?(.audioSampleBuffer(sampleBuffer))
        }
        try audioSession!.start()
    }
    
    func prepareMetalRender() throws {
        var result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, scnView.device!, nil, &textureCache)
        guard result == kCVReturnSuccess else {
            fatalError("Create texture cache failed: \(result)")
        }
        
        bufferPool = try PixelBufferPool(pixelBufferCount: 6, width: Int(videoSize.width), height: Int(videoSize.height),pixelFormat: kCVPixelFormatType_32BGRA)
        renderBuffer = try bufferPool?.createPixelBuffer()
        
        let textureAttributes = [kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary
        var metalTexture: CVMetalTexture?
        result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, renderBuffer!,
                                                           textureAttributes, .bgra8Unorm_srgb, bufferPool!.width, bufferPool!.height, 0, &metalTexture)
        guard result == kCVReturnSuccess else {
            throw CoreVideoError.failure(CVReturnValue(result))
        }
        guard let texture = CVMetalTextureGetTexture(metalTexture!) else {
            fatalError("Get texture failed")
        }
        renderTexture = texture
        
        videoRender = SCNRenderer(device: scnView.device, options: nil)
        videoRender!.scene = scnView.scene
        renderPass.colorAttachments[0].texture = renderTexture
    }
    
    /// Render the scene view content to pixel buffer.
    func renderToPixelBuffer(atTime time: TimeInterval) {
        guard isRunning else { return }
        
        let viewport = CGRect(origin: .zero, size: videoSize)
        let commandBuffer = videoRender?.commandQueue!.makeCommandBuffer()
        videoRender?.render(atTime: time, viewport: viewport, commandBuffer: commandBuffer!, passDescriptor: renderPass)
        videoRender?.scene = scnView.scene
        videoRender?.pointOfView = scnView.pointOfView
        
        commandBuffer?.addCompletedHandler({ [weak self] (_) in
            guard let buffer = self?.renderBuffer else { return }
            self?.outputPixelBuffer(from: buffer)
        })
        
        commandBuffer?.commit()
    }
    
    func outputPixelBuffer(from buffer: CVPixelBuffer) {
        
        do {
            let currentTime = CACurrentMediaTime()
            let time = CMTime(seconds: currentTime, preferredTimescale: timeScale)
            let pixelBuffer = try self.bufferPool!.createPixelBuffer(from: buffer)
            self.queue.async {
                self.trackDataHandler?(.videoPixelBuffer(pixelBuffer, time))
            }
        } catch {
            print("Create pixel buffer failed: \(error)")
        }
    }
}

//MARK: Takeover SCNView's Render Delegate

extension SCNViewTrackDataProvider: SCNSceneRendererDelegate {
    
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
