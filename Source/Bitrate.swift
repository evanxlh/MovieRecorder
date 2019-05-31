//
//  Bitrate.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/23.
//

import Foundation

public enum Quality: Int {
    case lowest
    case low
    case medium
    case high
    case highest
}

public enum BitsPerPixel: Equatable {
    case lowest
    case low
    case medium
    case high
    case highest
    case custom(Float)
    
    public var rawValue: Float {
        switch self {
        case .lowest:
            return 0.8
        case .low:
            return 1.5
        case .medium:
            return 4.3
        case .high:
            return 7.1
        case .highest:
            return 10.1
        case .custom(let bits):
            return bits
        }
    }
    
    public init(quality: Quality) {
        switch quality {
        case .lowest:
            self = .lowest
        case .low:
            self = .low
        case .medium:
            self = .medium
        case .high:
            self = .high
        case .highest:
            self = .highest
        }
    }
    
    public static func bitsPerPixel(by quality: Quality) -> BitsPerPixel {
        switch quality {
        case .lowest:
            return .lowest
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        case .highest:
            return .highest
        }
    }
    
    public static func == (lhs: BitsPerPixel, rhs: BitsPerPixel) -> Bool {
        switch (lhs, rhs) {
        case (.lowest, .lowest), (.low, .low), (.medium, .medium), (.high, .high), (.highest, .highest):
            return true
        case let (.custom(l), .custom(r)):
            return l == r
        default:
            return false
        }
    }
    
    public static func != (lhs: BitsPerPixel, rhs: BitsPerPixel) -> Bool {
        return !(lhs == rhs)
    }
}

public struct Bitrate: Equatable {
    
    public let rawValue: Float
    
    public init(_ bitrate: Float) {
        rawValue = bitrate
    }
    
    /// Init bitrate from video size and
    public init(videoWidth: Int,  videoHeight: Int, bitsPerPixel: BitsPerPixel) {
        rawValue = Float(videoWidth * videoHeight) * bitsPerPixel.rawValue
    }
    
    public init(videoWidth: Int,  videoHeight: Int, quality: Quality) {
        rawValue = Float(videoWidth * videoHeight) * BitsPerPixel(quality: quality).rawValue
    }
    
    public static func == (lhs: Bitrate, rhs: Bitrate) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public static func != (lhs: Bitrate, rhs: Bitrate) -> Bool {
        return lhs.rawValue != rhs.rawValue
    }
}

//MARK: - Common Audio Bitrate

extension Bitrate {
    
    /*:
     [MP3 Bit Rate: What Does It Mean?](https://www.lifewire.com/what-is-mp3-bitrate-2438538)
     [Choosing Audio Bitrate Settings](https://tritondigitalcommunity.force.com/s/article/Choosing-Audio-Bitrate-Settings)
     */
    
    /// Usually used only for spoken audio.
    public static let audio32k  = Bitrate(32000)
    
    /// Speech or low-quality streaming.
    public static let audio96k  = Bitrate(96000)
    
    /// Mid-range bit rate quality. A 4 minutes mp3 song requires over 3.5 MB of space.
    public static let audio128k = Bitrate(128000)
    
    /// Medium quality bit rate.
    public static let audio192k = Bitrate(192000)
    
    /// A commonly used high-quality bit rate.
    public static let audio256k = Bitrate(256000)
    
    /// The highest bit rate level that MP3 supports. CD quality, a 4 minutes mp3 song requires over 9 MB of space.
    public static let audio320k = Bitrate(320000)
}


