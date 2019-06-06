//
//  MovieRecorder.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/30.
//

import AVFoundation
import CoreMedia
import CoreVideo

/**
 Video file container type.
 */
public enum MovieFileType: Int {
    
    /// The value of this UTI is `com.apple.m4v-video`,
    /// file are identified with the `m4v` extension.
    case m4v
    
    /// The value of this UTI is `com.apple.quicktime-movie`,
    /// files are identified with the `mov` and `qt` extensions.
    case mov
    
    /// The value of this UTI is `public.mpeg-4`,
    /// file are identified with the `mp4` extension.
    case mp4
    
    public var rawType: AVFileType {
        return [AVFileType.m4v, AVFileType.mov, AVFileType.mp4][rawValue]
    }
    
    public var fileExtension: String {
        return ["m4v", "mov", "mp4"][rawValue]
    }
}


/**
 A universal movie recorder for your most usecase.
 It's full asychronously, non-block.
 
 How does movie recorder work?
 1. Create movie recorder, add the media sample source.
 2. Setup error handler to handle the errors
 3. Start recording, movie recorder will setup all the things, and start sample source.
 4. Stop recording, get the final movie file.
 */
public final class MovieRecorder: NSObject {
    
    fileprivate let movieFileURL: URL
    fileprivate let fileType: MovieFileType
    fileprivate var movieWriter: MovieWriter?
    
    fileprivate var internalState = State.stopped
    fileprivate var lock = MutexLock()
    
    fileprivate var startCompletionCallback: (() -> Void)?
    fileprivate var stopCompletionCallback: ((URL) -> Void)?
    
    fileprivate var hasAudioTrack = true
    fileprivate var audioFormatDescription: CMAudioFormatDescription?
    fileprivate var videoFormatDescription: CMVideoFormatDescription?
    
    /// Get current recorder state, it's thread safe.
    public var state: State {
        lock.lock()
        defer { lock.unlock() }
        return internalState
    }
    
    /// Check recorder is recording now or not, means recorder is started successfully.
    /// In this state, recorder can write audio/video buffer data to movie file.
    public var isRecording: Bool {
        return state == .recording
    }
    
    /// Handle recorder possible errors.
    public var errorHandler: ErrorHandler?
    
    /// You can specify the creator, copyright, and so on, by setting this metadata.
    public var metadata: [AVMetadataItem]?
    
    public init(outputURL: URL, sampleSources: [SampleSource], movieFileType: MovieFileType = .mov) {
        guard sampleSources.count > 0 else {
            fatalError("Movie recorder need sample data source.")
        }
        movieFileURL = outputURL
        fileType = movieFileType
    }
    
    /**
     Start recording. When successfully, callback block will be executed on the main thread.
     If failed, `errorHandler` will be executed on the main thread.
     */
    public func startRecording(completionBlock: @escaping (() -> Void)) {
        guard transitionToState(.starting) else {
            fatalError("Invalid state for transitioning to starting state.")
        }
        startCompletionCallback = completionBlock
        prepareToStart()
    }
    
    /**
     Stop recording. When successfully, callback block with the movie url will be executed on the main thread.
     If failed, `errorHandler` will be executed on the main thread.
     */
    public func stopRecording(completionBlock: @escaping ((URL) -> Void)) {
        guard transitionToState(.stopping) else {
            fatalError("Invalid state for transitioning to stopping state.")
        }
        stopCompletionCallback = completionBlock
        prepareToStop()
    }
}

extension MovieRecorder: MediaSampleConsumer {
    
    public func consumeMediaSample(_ mediaSample: MediaSample, source: SampleSource) {
        
    }
    
    public func handleSampleSourceError(_ error: Swift.Error, source: SampleSource) {
        
    }
}

public extension MovieRecorder {
    
    typealias ErrorHandler = (_ error: Error) -> Void
    
    enum Error: Swift.Error {
        
        /// Fail to start recorder
        case failedToStart(underlyingError: Swift.Error)
        
        /// Fail to stop recorder
        case failedToStop(underlyingError: Swift.Error)
        
        /// Fail to write more audio/video buffer data when recording.
        case failedToRecord(underlyingError: Swift.Error)
    }
    
    enum State: Int, CustomStringConvertible {
        case starting
        case recording
        case stopping
        case stopped
        case failed
        
        public var description: String {
            return ["starting", "recording", "stopping", "stopped", "failed"][rawValue]
        }
    }
}

extension MovieRecorder: MovieWriterDelegate {
    
    func movieWriterDidStart(_ writer: MovieWriter) {
        transitionToState(.recording)
        
        DispatchQueue.main.async {
            self.startCompletionCallback?()
            self.startCompletionCallback = nil
        }
    }
    
    func movieWriterDidFinish(_ writer: MovieWriter, movieOutputURL: URL) {
        transitionToState(.stopped)
        teardownWriter()
        
        if stopCompletionCallback == nil {
            DispatchQueue.global().async {
                try? FileManager.default.removeItem(at: movieOutputURL)
            }
        } else {
            DispatchQueue.main.async {
                self.stopCompletionCallback?(movieOutputURL)
                self.stopCompletionCallback = nil
            }
        }
    }
    
    func movieWriterDidFail(_ writer: MovieWriter, error: MovieWriter.Error) {
        stopProvider()
        handleError(error)
        teardownWriter()
    }
}

fileprivate extension MovieRecorder {
    
    var isReadyForSettingUpWriter: Bool {
        if hasAudioTrack {
            return audioFormatDescription != nil && videoFormatDescription != nil
        }
        
        return videoFormatDescription != nil
    }
    
    func extractFormatDescriptionIfNeed(from mediaSample: MediaSample) {
        switch mediaSample {
        case let .audioSampleBuffer(buffer):
            if audioFormatDescription == nil {
                audioFormatDescription = CMSampleBufferGetFormatDescription(buffer)
            }
        case let .videoSampleBuffer(buffer):
            if videoFormatDescription == nil {
                videoFormatDescription = CMSampleBufferGetFormatDescription(buffer)
            }
        case let .videoPixelBuffer(buffer, _):
            if videoFormatDescription == nil {
                videoFormatDescription = buffer.formatDescription
            }
        }
    }
    
    func prepareToStart() {
        
//        dataProvider.errorHandler = { [weak self] (error) in
//            self?.stopCompletionCallback = nil
//            self?.finishWriter()
//            self?.handleError(error)
//        }
//
//        dataProvider.trackDataHandler = { [weak self] (trackData) in
//            guard let strongSelf = self else { return}
//            strongSelf.extractFormatDescriptionIfNeed(from: trackData)
//
//            // If movie writer not start, but the audio/video format description are both obtained,
//            // so, we can start the writer.
//            if strongSelf.movieWriter == nil && strongSelf.isReadyForSettingUpWriter {
//                strongSelf.startWriter()
//            } else if strongSelf.movieWriter != nil {
//                strongSelf.appendTrackData(trackData)
//            }
//        }
//
//        dataProvider.startRunning { }
    }
    
    func prepareToStop() {
        stopProvider()
        finishWriter()
    }
    
    func stopProvider() {
//        dataProvider.errorHandler = nil
//        dataProvider.trackDataHandler = nil
//        dataProvider.stopRunning { }
    }
    
    func startWriter() {
        
        movieWriter = MovieWriter(outputURL: movieFileURL, fileType: fileType, delegateCallbackQueue: nil)
        movieWriter?.delegate = self
        
        if let audioFormat = audioFormatDescription {
            movieWriter?.addAudioTrack(sourceFormat: audioFormat, encodingSettings: nil)
        }
        if let videoFormat = videoFormatDescription {
            movieWriter?.addVideoTrack(sourceFormat: videoFormat, encodingSettings: nil, transform: nil)
        }
        
        movieWriter?.startWriting()
    }
    
    func appendMediaSample(_ mediaSample: MediaSample) {
        switch mediaSample {
        case let .audioSampleBuffer(buffer):
            movieWriter?.append(audioSampleBuffer: buffer)
        case let .videoSampleBuffer(buffer):
            movieWriter?.append(videoSampleBuffer: buffer)
        case let .videoPixelBuffer(buffer, time):
            movieWriter?.append(videoPixelBuffer: buffer, presentationTime: time)
        }
    }
    
    func finishWriter() {
        movieWriter?.finishWriting()
    }
    
    func teardownWriter() {
        movieWriter?.delegate = nil
        movieWriter = nil
    }
    
    func handleError(_ error: Swift.Error) {
        
        let oldState = state
        transitionToState(.failed)
        
        DispatchQueue.main.async {
            switch oldState {
            case .starting:
                self.errorHandler?(.failedToStart(underlyingError: error))
            case .stopping:
                self.errorHandler?(.failedToStop(underlyingError: error))
            case .recording:
                self.errorHandler?(.failedToRecord(underlyingError: error))
            default:
                // Never happen in other states.
                break
            }
        }
    }
    
    @discardableResult
    func transitionToState(_ newState: State) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard internalState.canTransitionToState(newState) else {
            return false
        }
        
        internalState = newState
        return true
    }
    
}

fileprivate extension MovieRecorder.State {
    
    func canTransitionToState(_ newState: MovieRecorder.State) -> Bool {
        return transitableStates.contains(newState)
    }
    
    //MARK: - Private
    
    /// The states to which current state can be transitioned.
    private var transitableStates: [MovieRecorder.State] {
        switch self {
        case .starting:
            return startingTransitableStates
        case .recording:
            return recordingTransitableStates
        case .stopping:
            return stoppingTransitableStates
        case .stopped:
            return stoppedTransitableStates
        case .failed:
            return failedTransitableStates
        }
    }
    
    private var startingTransitableStates: [MovieRecorder.State] {
        return [.recording, .failed]
    }
    
    private var recordingTransitableStates: [MovieRecorder.State] {
        return [.stopping, .failed]
    }
    
    private var stoppingTransitableStates: [MovieRecorder.State] {
        return [.stopped, .failed]
    }
    
    private var stoppedTransitableStates: [MovieRecorder.State] {
        return [.starting]
    }
    
    private var failedTransitableStates: [MovieRecorder.State] {
        return [.starting]
    }
}
