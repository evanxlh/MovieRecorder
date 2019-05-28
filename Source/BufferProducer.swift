//
//  BufferProducer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/24.
//

import CoreMedia
import CoreVideo

public enum BufferType: Int {
    case audioSampleBuffer
    case videoSampleBuffer
    case videoPixelBuffer
}

public enum TimeScale {
    case systemDefault
    case custom(CMTimeScale)
    
    private static let systemTimeScaleRawValue = CMClockGetTime(CMClockGetHostTimeClock()).timescale
    
    var rawValue: CMTimeScale {
        switch self {
        case .systemDefault:
            return TimeScale.systemTimeScaleRawValue
        case .custom(let ts):
            return ts
        }
    }
    
    var isSystemDefault: Bool {
        switch self {
        case .systemDefault:
            return true
        case .custom(let ts):
            return TimeScale.systemTimeScaleRawValue == ts
        }
    }
}

public enum Buffer {
    case audioSampleBuffer(CMSampleBuffer)
    case videoSampleBuffer(CMSampleBuffer)
    case videoPixelBuffer(CVPixelBuffer, CMTime)
    
    public var type: BufferType {
        switch self {
        case .audioSampleBuffer:
            return .audioSampleBuffer
        case .videoSampleBuffer:
            return .videoSampleBuffer
        case .videoPixelBuffer:
            return .videoPixelBuffer
        }
    }
}

public protocol BufferProducerDelegate: class {
    func bufferProducer(_ producer: BufferProducer, didOutput buffer: Buffer)
    func bufferProducer(_ producer: BufferProducer, didFail error: Error)
}

public protocol BufferProducer: class {
    
    var timeScale: TimeScale { get set }
    
    /**
     Start buffer producer, and output buffer periodicity.
     
     If failed to start, `delegate.bufferProducerDidFailToStart` will be invoked.
     */
    func start()
    
    /**
     Stop buffer producer producing more buffers.
     */
    func stop()
}



