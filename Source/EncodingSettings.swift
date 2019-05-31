//
//  TrackConfiguration.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/23.
//

import AVFoundation
import CoreVideo

/**
 Audio encoding settings for the output movie file.
 Only supports `kAudioFormatMPEG4AAC`.
 */
public struct AudioEncodingSettings {
    
    public static let lowest = AudioEncodingSettings(bitrate: .audio32k)
    public static let low = AudioEncodingSettings(bitrate: .audio96k)
    public static let medium = AudioEncodingSettings(bitrate: .audio128k)
    public static let high = AudioEncodingSettings(bitrate: .audio192k)
    public static let highest = AudioEncodingSettings(bitrate: .audio256k)
    
    /// Audio sample rate in hz.
    public var sampleRate: Float
    public var bitrate: Bitrate
    
    public init(sampleRate: Float = 44100, bitrate: Bitrate = Bitrate.audio128k) {
        self.sampleRate = sampleRate
        self.bitrate = bitrate
    }
    
    public func toParams() -> [String: Any] {
        
        var layout = AudioChannelLayout()
        layout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
        let data = Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)
        
        return [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: sampleRate,
            AVEncoderBitRateKey: bitrate.rawValue,
            AVChannelLayoutKey: data
        ]
    }
}

/**
 Video encoding settings for the output movie file.
 Here use h264 codec to compress video frame.
 */
public struct VideoEncodingSettings {
    
    /// Video pixel width
    public var width: Int
    
    /// Video pixel width
    public var height: Int
    
    /// Video framerate
    public var framerate: Int
    
    public var bitrate: Bitrate
    
    public init(width: Int, height: Int, framerate: Int, bitrate: Bitrate) {
        self.width = width
        self.height = height
        self.framerate = framerate
        self.bitrate = bitrate
    }
    
    public init(width: Int, height: Int, framerate: Int, quality: Quality = .medium) {
        self.width = width
        self.height = height
        self.framerate = framerate
        self.bitrate = Bitrate(videoWidth: width, videoHeight: height, quality: quality)
    }
    
    func toParams() -> [String: Any] {
        
        let compressionProperties = [
            AVVideoAverageBitRateKey: bitrate.rawValue,
            AVVideoExpectedSourceFrameRateKey: framerate,
            AVVideoMaxKeyFrameIntervalKey: framerate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
        ] as [String : Any]
        
        return [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey : compressionProperties
        ]
    }
}

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
