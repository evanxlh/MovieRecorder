//
//  MovieWriter.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/23.
//

import AVFoundation

public protocol MovieWriterDelegate: class {
    func movieWriterDidStart(_ writer: MovieWriter)
    func movieWriterDidStop(_ writer: MovieWriter, movieOutputURL: URL)
    func movieWriterDidCancel(_ writer: MovieWriter)
    func movieWriterDidFail(_ writer: MovieWriter, error: MovieWriter.Error)
}

/**
 A completely asychronouse movie writer for recording movie.
 It's designed for read-time movie recording without blocking main thread.
 
 **Workflow**:
 1. Create movie writer
 2. Add audio/video track
 3. start writer
 4. append sample buffer
 5. stop writer
 
 Reference: [Apple Sample: RosyWriter](https://github.com/robovm/apple-ios-samples/tree/master/RosyWriter)
 */
public final class MovieWriter {
    
    //MARK: - Private Properties
    
    fileprivate var outputURL: URL
    fileprivate var fileType: MovieFileType
    fileprivate var metadata: [AVMetadataItem]?
    
    fileprivate var assetWriter: AVAssetWriter?
    fileprivate var audioWriterInput: AVAssetWriterInput?
    fileprivate var videoWriterInput: AVAssetWriterInput?
    
    fileprivate var audioSettings: AudioEncodingSettings?
    fileprivate var videoSettings: VideoEncodingSettings?
    fileprivate var videoTransform: CGAffineTransform?
    
    fileprivate var locker = MutexLock()
    fileprivate var writeQueue = DispatchQueue(label: "MovieRecorder.WriteQueue")
    fileprivate var delegateQueue: DispatchQueue
    
    fileprivate var state = State.stopped
    fileprivate var sessionStarted = false
    
    fileprivate var isSessionStarted: Bool {
        locker.lock()
        defer { locker.unlock() }
        return sessionStarted
    }
    
    fileprivate var syncedState: State {
        locker.lock()
        defer { locker.unlock() }
        return state
    }
    
    //MARK: -
    
    public enum Error: Swift.Error {
        case unsupportedTrackEncodingSettings([String: Any])
        case underlyingError(NSError)
    }
    
    public weak var delegate: MovieWriterDelegate?
    
    /// Indicates movie writer is ready for appending sample buffer or not.
    /// Only when `true`, you can append sample buffer.
    public var isWriting: Bool {
        return syncedState == .writing
    }

    /**
     Init with movie file saved url, movie file container type and delegate callback queue.
     Delegate will be invoked on the main thread default if no callback queue is specified.
     */
    public init(outputURL: URL, fileType: MovieFileType = .mp4, delegateCallbackQueue: DispatchQueue = .main) {
        self.outputURL = outputURL
        self.fileType = fileType
        self.delegateQueue = delegateCallbackQueue
    }
    
    //MARK: - Configurate Audio/Video Tracks
    
    public func addAudioTrack(encodingSettings: AudioEncodingSettings) {
        locker.lock()
        defer { locker.unlock() }
        
        guard state == .stopped || state == .failed else {
            fatalError("Please add audio track before writer starting.")
        }
        self.state = .stopped
        self.audioSettings = encodingSettings
    }
    
    public func addVideoTrack(encodingSettings: VideoEncodingSettings, transform: CGAffineTransform? = nil) {
        locker.lock()
        defer { locker.unlock() }
        
        guard state == .stopped || state == .failed else {
            fatalError("Please add video track before writer starting.")
        }
        self.state = .stopped
        self.videoSettings = encodingSettings
        self.videoTransform = transform
    }
}

extension MovieWriter {
    
    //MARK: - MovieWriter Control
    
    /**
     Start movie writer asynchronously.
     When start successfully, `movieWriterDidStart` delegate function will be invoked.
     If failed, `movieWriterDidFail` delegate function will be invoked.
     */
    public func start() {
        locker.lock()
        if audioSettings == nil && videoSettings == nil {
            fatalError("No track added, please add audio/video tracks before writer starting.")
        }
        locker.unlock()
        
        guard transitionToState(.starting) else {
            fatalError("Can not start movie writer in current state: \(state.description)")
        }
        
        writeQueue.async { [weak self] in
            self?.prepareWriter()
        }
    }
    
    public func stop() {
        guard transitionToState(.stoppingPhase1) else {
            print("[Warning]: Can not stop movie writer in current state: \(state.description)")
            return
        }
        
        writeQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            // Maybe movie writer enters `stopped` state. In that case, just return.
            guard strongSelf.syncedState == .stoppingPhase1 else { return }
            
            // It is not safe to call `finishWriting` concurrently with `appendSampleBuffer`, so we transition to
            // `stoppingPhase2` while on writingQueue, which guarantees that no more buffers will be appended.
            strongSelf.transitionToState(.stoppingPhase2)
            
            strongSelf.assetWriter!.finishWriting {
                if let error = strongSelf.assetWriter!.error as NSError? {
                    strongSelf.transitionToState(.failed, error: Error.underlyingError(error))
                } else {
                    strongSelf.transitionToState(.stopped)
                }
            }
        }
    }
    
    public func cancel() {
        
        guard transitionToState(.cancelling) else {
            print("[Warning]: Movie writer is not writing, no need cancelling.")
            return
        }
        
        writeQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            guard strongSelf.syncedState == .cancelling else { return }
            
            self?.assetWriter?.cancelWriting()
            strongSelf.transitionToState(.stopped)
        }
    }
    
    //MARK: - Write Audio/Video SampleBuffer
    
    public func append(audioSampleBuffer: CMSampleBuffer) {
        validateVideoSampleBufferAppendOperation()
        append(sampleBuffer: audioSampleBuffer, track: .audio)
    }
    
    public func append(videoSampleBuffer: CMSampleBuffer) {
        validateVideoSampleBufferAppendOperation()
        append(sampleBuffer: videoSampleBuffer, track: .video)
    }
    
    public func append(videoPixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        validateVideoSampleBufferAppendOperation()
        
        var sampleBuffer: CMSampleBuffer?
        var videoFD: CMVideoFormatDescription?
        var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: presentationTime, decodeTimeStamp: .invalid)
        
        var errorCode = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: videoPixelBuffer,
                                                                     formatDescriptionOut: &videoFD)
        if videoFD == nil {
            fatalError("Create video format description failed: \(errorCode)")
        }
        
        errorCode = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: videoPixelBuffer, dataReady: true,
                                                       makeDataReadyCallback: nil, refcon: nil, formatDescription: videoFD!, sampleTiming: &timingInfo, sampleBufferOut: &sampleBuffer)
        if sampleBuffer == nil {
            fatalError("Create video sample buffer failed: \(errorCode)")
        }
        
        append(sampleBuffer: sampleBuffer!, track: .video)
    }
}

//MARK: - Private Functions

fileprivate extension MovieWriter {
    
    @discardableResult
    func transitionToState(_ newState: State, error: Error? = nil) -> Bool {
        locker.lock()
        defer { locker.unlock() }
        
        guard state.canTransitionToState(newState) else {
            return false
        }
        
        if state != newState {
            state = newState
            
            delegateQueue.async {
                self.handleCallbackDelegate(state: newState, error: error)
            }
        }
        
        return true
    }
    
    func handleCallbackDelegate(state: State, error: Error?) {
        switch state {
        case .cancelled:
            writeQueue.async { self.cleanAll() }
            delegate?.movieWriterDidCancel(self)
        case .failed:
            writeQueue.async { self.cleanAll() }
            delegate?.movieWriterDidFail(self, error: error!)
        case .stopped:
            writeQueue.async { self.tearDownWriter() }
            delegate?.movieWriterDidStop(self, movieOutputURL: outputURL)
        case .writing:
            delegate?.movieWriterDidStart(self)
        default:
            break
        }
    }
    
    func prepareWriter() {
        
        do {
            removeResidualMovieFile()
            assetWriter = try AVAssetWriter(url: outputURL, fileType: fileType.rawType)
            if metadata != nil {
                assetWriter!.metadata = metadata!
            }
            if audioSettings != nil {
                try setupAudioInput()
            }
            if videoSettings != nil {
                try setupVideoInput()
            }
            
            guard assetWriter!.startWriting() else {
                throw assetWriter!.error! as NSError
            }
            
            transitionToState(.writing, error: nil)
            
        } catch {
            transitionToState(.failed, error: .underlyingError(error as NSError))
        }
    }
    
    func setupAudioInput() throws {
        
        let rawSettings = audioSettings!.toParams()
        guard assetWriter!.canApply(outputSettings: rawSettings, forMediaType: .audio) else {
            throw Error.unsupportedTrackEncodingSettings(rawSettings)
        }
        
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings!.toParams())
        audioWriterInput!.expectsMediaDataInRealTime = true
        assetWriter!.add(audioWriterInput!)
    }
    
    func setupVideoInput() throws {
        
        let rawSettings = videoSettings!.toParams()
        guard assetWriter!.canApply(outputSettings: rawSettings, forMediaType: .video) else {
            throw Error.unsupportedTrackEncodingSettings(rawSettings)
        }
        
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: rawSettings)
        videoWriterInput!.expectsMediaDataInRealTime = true
        if videoTransform != nil {
            videoWriterInput!.transform = videoTransform!
        }
        assetWriter!.add(videoWriterInput!)
    }
    
    func validateVideoSampleBufferAppendOperation() {
        guard syncedState == .writing else {
            fatalError("Can not append video sample buffer in current state: \(state).")
        }
        guard videoSettings != nil else {
            fatalError("No video track added.")
        }
    }
    
    func append(sampleBuffer: CMSampleBuffer, track: Track) {
        
        writeQueue.async {
            guard self.syncedState == .writing else {
                print("Can not append sample buffer in current state: \(self.state)")
                return
            }
            
            if !self.isSessionStarted {
                self.assetWriter!.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                self.sessionStarted = true
            }
            
            let input = (track == .video) ?  self.videoWriterInput! : self.audioWriterInput!
            if input.isReadyForMoreMediaData {
                if !input.append(sampleBuffer) {
                    if self.assetWriter!.status == .failed {
                        self.transitionToState(.failed, error: .underlyingError(self.assetWriter!.error! as NSError))
                    }
                }
            } else {
                print("\(input.debugName) is not ready for appending sample buffer, so dropping buffer.")
            }
        }
    }
    
    func removeResidualMovieFile() {
        try? FileManager.default.removeItem(at: outputURL)
    }
    
    func tearDownWriter() {
        audioWriterInput = nil
        videoWriterInput = nil
        assetWriter = nil
    }
    
    func cleanAll() {
        removeResidualMovieFile()
        tearDownWriter()
    }
}

fileprivate extension AVAssetWriterInput {
    
    var debugName: String {
        switch mediaType {
        case .audio:
            return "Audio input"
        case .video:
            return "Video input"
        default:
            return "Other"
        }
    }
}
