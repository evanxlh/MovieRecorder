//
//  SCNViewRecorder.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/24.
//

import SceneKit

public class SCNViewRecorder: Recordable {
    
    fileprivate let scnView: SCNView
    fileprivate var scnViewOriginDelegate: SCNSceneRendererDelegate?
    
    fileprivate var audioProducer: SystemAudioVideoProducer?
    fileprivate var movieWriter: MovieWriter
    
    fileprivate var internalState = RecorderState.stopped
    fileprivate var lock = MutexLock()
    
    fileprivate var startCallback: RecorderStartCallback?
    fileprivate var stopCallback: RecorderStopCallback?
    
    public var configuration: RecorderConfiguration
    
    public var state: RecorderState {
        lock.lock()
        defer { lock.unlock() }
        return internalState
    }
    
    public var isRecording: Bool {
        return state == .recording
    }
    
    public init(scnView: SCNView, configuration: RecorderConfiguration) {
        self.scnView = scnView
        self.configuration = configuration
        self.movieWriter = MovieWriter(outputURL: configuration.outputURL)
    }
    
    deinit {
        giveBackRenderDelegate()
    }
    
    public func start(callback: @escaping (Result<Void, Error>) -> Void) {
        guard transitionToState(.starting) else {
            fatalError("Invalid state for transitioning to starting state.")
        }
        startCallback = callback
        takeoverRenderDelegate()
        movieWriter.start()
    }
    
    public func stop(callback: @escaping (Result<URL, Error>) -> Void) {
        guard transitionToState(.stopping) else {
            fatalError("Invalid state for transitioning to stopping state.")
        }
        stopCallback = callback
        giveBackRenderDelegate()
        movieWriter.stop()
    }
    
}

fileprivate extension SCNViewRecorder {
    
    @discardableResult
    func transitionToState(_ newState: RecorderState) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard internalState.canTransitionToState(newState) else {
            return false
        }
        
        internalState = newState
        return true
    }
}

extension SCNViewRecorder: BufferProducerDelegate {
    
    func setupBufferProducer() throws {
        
        if configuration.isAudioActive {
            audioProducer = try SystemAudioVideoProducer(mode: .audio)
            audioProducer?.delegate = self
        }
        
        
    }
    
    public func bufferProducer(_ producer: BufferProducer, didOutput buffer: Buffer) {
        switch buffer {
        case .audioSampleBuffer(let sampleBuffer):
            movieWriter.append(audioSampleBuffer: sampleBuffer)
        case let .videoPixelBuffer(pixelBuffer, presentationTime):
            movieWriter.append(videoPixelBuffer: pixelBuffer, presentationTime: presentationTime)
        default:
            // Will not happen.
            return
        }
    }
    
    public func bufferProducer(_ producer: BufferProducer, didFail error: Error) {
        transitionToState(.failed)
    }
}

extension SCNViewRecorder: MovieWriterDelegate {
    
    public func movieWriterDidStart(_ writer: MovieWriter) {
        transitionToState(.recording)
        startCallback?(.success(()))
        startCallback = nil
    }
    
    public func movieWriterDidStop(_ writer: MovieWriter, movieOutputURL: URL) {
        transitionToState(.stopped)
        stopCallback?(.success(configuration.outputURL))
    }
    
    public func movieWriterDidCancel(_ writer: MovieWriter) {
        // Recorder doesn't implement cancelling, so do nothing.
    }
    
    public func movieWriterDidFail(_ writer: MovieWriter, error: MovieWriter.Error) {
        
        let oldState = state
        transitionToState(.failed)
        
        switch oldState {
        case .starting:
            startCallback?(.failure(error))
        case .stopping:
            stopCallback?(.failure(error))
        case .recording:
            //TODO:
            break
        default:
            break
        }
    }
}

//MARK: Takeover SCNView's Render Delegate

fileprivate extension SCNViewRecorder {
    
    func takeoverRenderDelegate() {
        scnViewOriginDelegate = scnView.delegate
        scnView.delegate = self as? SCNSceneRendererDelegate
    }
    
    func giveBackRenderDelegate() {
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
        scnViewOriginDelegate?.renderer?(renderer, willRenderScene: scene, atTime: time)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        scnViewOriginDelegate?.renderer?(renderer, didRenderScene: scene, atTime: time)
    }
}
