//
//  ProducerConsumer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/4.
//

import CoreMedia
import CoreVideo

/// The media track types which movie recorder supports.
public enum MovieTrackType: Int {
    case audio
    case video
}

/// The data struct for representing sample data which auido/video producer produces.
public enum MediaSample {
    case audioSampleBuffer(CMSampleBuffer)
    case videoSampleBuffer(CMSampleBuffer)
    case videoPixelBuffer(CVPixelBuffer, CMTime)
    
    public var trackType: MovieTrackType {
        switch self {
        case .audioSampleBuffer:
            return .audio
        case .videoPixelBuffer, .videoSampleBuffer:
            return .video
        }
    }
    
    public var isAudioTrack: Bool {
        return trackType == .audio
    }
    
    public var isVideoTrack: Bool {
        return trackType == .video
    }
}

/**
 An example:
 
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
public typealias AudioEncodingSettings = [String: Any]

/**
 An example:
 
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
public typealias VideoEncodingSettings = [String: Any]

/// The sample data encoding settings which is recommended by producer.
public enum MediaSampleRecommendedEncodingSettings {
    case audio(AudioEncodingSettings)
    case video(VideoEncodingSettings)
}

//MARK: - Audio/Video Sample Producer

public enum ProducerType: Int {
    
    /// Producing audio sample data.
    case audio
    
    /// Producing video sample data.
    case video
}

public protocol MediaSampleProducer {
    
    var isRunning: Bool { get }
    
    var producerType: ProducerType { get }
    
    var sampleConsumers: SampleConsumerContainer { get }
    
    func startRunning() throws
    
    func stopRunning()
    
    func recommendedSettingsForFileType(_ fileType: MovieFileType) -> [String: Any]?
}

public extension MediaSampleProducer {
    
    func recommendedSettingsForFileType(_ fileType: MovieFileType) -> [String: Any]? {
        return nil
    }
    
    func addMediaSampleConsumer(_ consumer: MediaSampleConsumer) {
        sampleConsumers.append(consumer)
    }
    
    func removeMediaSampleConsumer(_ consumer: MediaSampleConsumer) {
        sampleConsumers.remove(consumer)
    }
    
    func removeAllMediaSampleConsumers() {
        sampleConsumers.removeAll()
    }
    
    func notifyConsumersWhenMediaSampleReady(_ mediaSample: MediaSample) {
        let producer = self
        sampleConsumers.forEach {
            $0.consumeMediaSample(mediaSample, producer: producer)
        }
    }
    
    func notifyConsumersWhenProducerOccursError(_ error: Swift.Error) {
        let producer = self
        sampleConsumers.forEach {
            $0.handleMediaSampleProducerError(error, producer: producer)
        }
    }
}

//MARK: - Audio/Video Sample Consumer

public protocol MediaSampleConsumer: NSObjectProtocol {
    
    func consumeMediaSample(_ mediaSample: MediaSample, producer: MediaSampleProducer)
    
    func handleMediaSampleProducerError(_ error: Swift.Error, producer: MediaSampleProducer)
}

public class SampleConsumerContainer: Sequence {
    fileprivate var content: [WeakMediaSampleConsumer]
    
    public init() {
        content = [WeakMediaSampleConsumer]()
    }
    
    public func append(_ consumer: MediaSampleConsumer) {
        content.append(WeakMediaSampleConsumer(consumer))
    }
    
    public func remove(_ consumer: MediaSampleConsumer) {
        let index = content.firstIndex {
            guard let value = $0.value else { return false }
            return consumer.isEqual(value)
        }
        if index != nil {
            content.remove(at: index!)
        }
    }
    
    public func removeAll() {
        content.removeAll()
    }
    
    public __consuming func makeIterator() -> AnyIterator<MediaSampleConsumer> {
        var index: Int = 0
        return AnyIterator { () -> MediaSampleConsumer? in
            guard index < self.content.count else {  return nil }
            while self.content[index].value == nil {
                self.content.remove(at: index)
                guard index < self.content.count else {
                    return nil
                }
            }
            
            index += 1
            return self.content[index - 1].value
        }
    }
}

fileprivate class WeakMediaSampleConsumer {
    weak var value: MediaSampleConsumer?
    init(_ value: MediaSampleConsumer) {
        self.value = value
    }
}
