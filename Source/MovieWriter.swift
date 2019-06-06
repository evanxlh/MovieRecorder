//
//  MovieWriter.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/23.
//

import AVFoundation

 protocol MovieWriterDelegate: class {
    func movieWriterDidStart(_ writer: MovieWriter)
    func movieWriterDidFinish(_ writer: MovieWriter, movieOutputURL: URL)
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
 internal final class MovieWriter {
    
    //MARK: - Private Properties
    
    fileprivate var outputURL: URL
    fileprivate var fileType: MovieFileType
    fileprivate var metadata: [AVMetadataItem]?
    
    fileprivate var assetWriter: AVAssetWriter?
    fileprivate var audioWriterInput: AVAssetWriterInput?
    fileprivate var videoWriterInput: AVAssetWriterInput?
    
    fileprivate var audioSettings: [String: Any]?
    fileprivate var audioSourceFormat: CMAudioFormatDescription?
    
    fileprivate var videoSettings: [String: Any]?
    fileprivate var videoSourceFormat: CMVideoFormatDescription?
    fileprivate var videoTransform: CGAffineTransform?
    
    fileprivate var locker = MutexLock()
    fileprivate var workingQueue = DispatchQueue(label: "MovieWriter.WorkingQueue")
    fileprivate var delegateQueue: DispatchQueue?
    
    fileprivate var state = State.idle
    fileprivate var isSessionStarted = false
    
    fileprivate var syncedState: State {
        locker.lock()
        defer { locker.unlock() }
        return state
    }
    
    //MARK: - APIs
    
     enum Error: Swift.Error {
        case unsupportedTrackEncodingSettings([String: Any])
        case underlyingError(NSError)
    }
    
     weak var delegate: MovieWriterDelegate?
    
    /// Indicates movie writer is ready for appending sample buffer or not.
    /// Only when `true`, you can append sample buffer.
     var isWriting: Bool {
        return syncedState == .writing
    }

    /**
     Init with movie file saved url, movie file container type and delegate callback queue.
     Delegate will be invoked on the internal queue if no callback queue specified.
     */
     init(outputURL: URL, fileType: MovieFileType = .mov, delegateCallbackQueue: DispatchQueue? = nil) {
        self.outputURL = outputURL
        self.fileType = fileType
        self.delegateQueue = delegateCallbackQueue
    }
    
    //MARK: - Configurate Audio/Video Tracks
    
    /**
     Add audio track for appending audio sample buffer. If the given encodingSettings settings is nil,
     movie writer will compute the encoding settings based audio source format.
     
     Make sure add audio track before movie writer starting.
     
     - An example of encoding settings:
     
     ```
     var layout = AudioChannelLayout()
     layout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
     let layoutData = Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)
     
     let audioSettings =  [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 1,
        AVSampleRateKey: 44100,
        AVChannelLayoutKey : layoutData,
        AVEncoderBitRateKey: 128000
     ]
     ```
     */
    func addAudioTrack(sourceFormat: CMAudioFormatDescription, encodingSettings: [String: Any]? = nil) {
        guard transitionToState(.idle) else {
            fatalError("Can not add audio track in current state.")
        }
        self.audioSourceFormat = sourceFormat
        self.audioSettings = encodingSettings
    }
    
    /**
     Add video track for appending video frame buffer. If the given encodingSettings settings is nil,
     movie writer will compute the encoding settings based video source format.
     
     Make sure add video track before movie writer starting.
     
     - An example of encoding settings:
     
     ```
     let compressionProperties = [
        AVVideoAverageBitRateKey: Float(3840 * 2160) * 10.1,
        AVVideoExpectedSourceFrameRateKey: 30,
        AVVideoMaxKeyFrameIntervalKey: 30,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
     ] as [String : Any]
     
     let videoSettings =  [
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: 3840,
        AVVideoHeightKey: 2160,
        AVVideoCompressionPropertiesKey : compressionProperties
     ]
     ```
     */
    func addVideoTrack(sourceFormat: CMVideoFormatDescription, encodingSettings: [String: Any]? = nil, transform: CGAffineTransform? = nil) {
        guard transitionToState(.idle) else {
            fatalError("Can not add video track in current state.")
        }
        self.videoSourceFormat = sourceFormat
        self.videoSettings = encodingSettings
        self.videoTransform = transform
    }
    
    //MARK: - Start/Finish
    
    /**
     Start movie writer asynchronously.
     When start successfully, `movieWriterDidStart` delegate function will be invoked.
     If failed, `movieWriterDidFail` delegate function will be invoked.
     */
     func startWriting() {
        locker.autoLock { [unowned self] in
            if self.audioSourceFormat == nil && self.videoSourceFormat == nil {
                fatalError("No media track added, please add audio/video tracks before writer starting.")
            }
        }
        
        guard transitionToState(.starting) else {
            print("Can not start movie writer in current state: \(state.description)")
            return
        }
        
        self.workingQueue.async { [weak self] in
            self?.prepareWriter()
        }
    }
    
    /**
     Finish writing asychronously, prevent any more sample data appending.
     */
    func finishWriting() {
        guard transitionToState(.finishingPhase1) else {
            print("Can not stop movie writer in current state: \(state.description)")
            return
        }
        
        workingQueue.async {
            
            // Maybe movie writer enters `stopped` state. In that case, just return.
            guard self.syncedState == .finishingPhase1 else { return }
            
            // It is not safe to call `finishWriting` concurrently with `appendSampleBuffer`, so we transition to
            // `finishingPhase2` while on writingQueue, which guarantees that no more buffers will be appended.
            self.transitionToState(.finishingPhase2)
            
            self.assetWriter!.finishWriting {
                if let error = self.assetWriter!.error as NSError? {
                    self.transitionToState(.failed, error: Error.underlyingError(error))
                } else {
                    self.transitionToState(.finished)
                }
            }
        }
    }
    
    //MARK: - Write Audio/Video SampleBuffer
    
     func append(audioSampleBuffer: CMSampleBuffer) {
        guard canAppendAudioFrameBuffer() else { return }
        append(sampleBuffer: audioSampleBuffer, track: .audio)
    }
    
     func append(videoSampleBuffer: CMSampleBuffer) {
        guard canAppendVideoFrameBuffer() else { return }
        append(sampleBuffer: videoSampleBuffer, track: .video)
    }
    
     func append(videoPixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard canAppendVideoFrameBuffer() else { return }
        
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: presentationTime, decodeTimeStamp: .invalid)
        
        let errorCode = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: videoPixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: videoSourceFormat!, sampleTiming: &timingInfo, sampleBufferOut: &sampleBuffer)
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
            
            var queue = delegateQueue
            if queue == nil {
                queue = workingQueue
            }
            queue!.async {
                self.handleCallbackDelegate(state: newState, error: error)
            }
        }
        
        return true
    }
    
    func handleCallbackDelegate(state: State, error: Error?) {
        switch state {
        case .failed:
            workingQueue.async { self.cleanAll() }
            delegate?.movieWriterDidFail(self, error: error!)
        case .finished:
            workingQueue.async { self.tearDownWriter() }
            delegate?.movieWriterDidFinish(self, movieOutputURL: outputURL)
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
            if audioSourceFormat != nil {
                try setupAudioInput()
            }
            if videoSourceFormat != nil {
                try setupVideoInput()
            }
            
            // Although I run it on the global queue, startWriting still let video preview stuck for a short time.
            // I asked help for Apple code-level support, still wait Apple feedback.
            // https://stackoverflow.com/questions/54820185/avassetwriter-momentary-lag-when-starting-write
            guard assetWriter!.startWriting() else {
                throw assetWriter!.error! as NSError
            }
            
            transitionToState(.writing, error: nil)
            
        } catch {
            transitionToState(.failed, error: .underlyingError(error as NSError))
        }
    }
    
    func setupAudioInput() throws {
        
        if audioSettings == nil || audioSettings!.isEmpty {
            audioSettings = [AVFormatIDKey: kAudioFormatMPEG4AAC] as [String: Any]
        }
        
        guard assetWriter!.canApply(outputSettings: audioSettings, forMediaType: .audio) else {
            throw Error.unsupportedTrackEncodingSettings(audioSettings!)
        }
        
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings, sourceFormatHint: audioSourceFormat)
        audioWriterInput!.expectsMediaDataInRealTime = true
        assetWriter!.add(audioWriterInput!)
    }
    
    func setupVideoInput() throws {
        
        if videoSettings == nil || videoSettings!.isEmpty {
            let dimension = CMVideoFormatDescriptionGetDimensions(videoSourceFormat!)
            let compressionProperties = [
                AVVideoAverageBitRateKey: Float(dimension.width * dimension.height) * 10.1,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
                ] as [String : Any]
            
            videoSettings =  [
                AVVideoCodecKey: AVVideoCodecH264,
                AVVideoWidthKey: dimension.width,
                AVVideoHeightKey: dimension.height,
                AVVideoCompressionPropertiesKey : compressionProperties
            ]
        }
        
        guard assetWriter!.canApply(outputSettings: videoSettings, forMediaType: .video) else {
            throw Error.unsupportedTrackEncodingSettings(videoSettings!)
        }
        
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings, sourceFormatHint: videoSourceFormat)
        videoWriterInput!.expectsMediaDataInRealTime = true
        if videoTransform != nil {
            videoWriterInput!.transform = videoTransform!
        }
        assetWriter!.add(videoWriterInput!)
    }
    
    func canAppendAudioFrameBuffer() -> Bool {
        guard syncedState == .writing else { return false }
        guard audioSourceFormat != nil else {
            fatalError("No video track added.")
        }
        return true
    }
    
    func canAppendVideoFrameBuffer() -> Bool {
        guard syncedState == .writing else { return false }
        guard videoSourceFormat != nil else {
            fatalError("No video track added.")
        }
        return true
    }
    
    func append(sampleBuffer: CMSampleBuffer, track: Track) {
        
        workingQueue.async {
            guard self.syncedState == .writing else {
                print("Can not append sample buffer in current state: \(self.state)")
                return
            }
            
            // Makesure the video doesn't appear black frame in the beginning.
            if !self.isSessionStarted && track == .video {
                self.assetWriter!.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                self.isSessionStarted = true
            }
            
            guard self.isSessionStarted else { return }
            
            let input: AVAssetWriterInput
            if track == .video {
                input = self.videoWriterInput!
            } else {
                input = self.audioWriterInput!
            }
            
            if input.isReadyForMoreMediaData {
                if !input.append(sampleBuffer) {
                    if self.assetWriter!.status == .failed {
                        self.transitionToState(.failed, error: .underlyingError(self.assetWriter!.error! as NSError))
                    } else {
                        print("\(input.debugName) append sample buffer failed, so dropping buffer.")
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
