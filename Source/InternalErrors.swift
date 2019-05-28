//
//  AVUnderlyingErrors.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/28.
//

import CoreVideo

internal extension Int32 {
    
     var fourCharacterCodeString: String {
        let utf16 = [
            UInt16((self >> 24) & 0xFF),
            UInt16((self >> 16) & 0xFF),
            UInt16((self >> 8) & 0xFF),
            UInt16((self & 0xFF))
        ]
        return String(utf16CodeUnits: utf16, count: 4)
    }
}

/**
 The error code wrapper for the return value of an operation in `CoreVideo.framework`.
 
 For `CVReturn`, `OSStatus`, you can find the error code detail meaning from
 [Apple Error Codes Lookup](https://www.osstatus.com).
 */
internal struct CVReturnValue: Equatable {
    let value: CVReturn
    
    init(_ value: CVReturn) {
        self.value = value
    }
    
    var fourCharacterCodeString: String {
        return value.fourCharacterCodeString
    }
    
    var description: String {
        switch value {
        case kCVReturnInvalidArgument:
            return "\(value): At least one of the arguments passed in is not valid. Either out of range or the wrong type."
        case kCVReturnAllocationFailed:
            return "\(value): The allocation for a buffer or buffer pool failed. Most likely because of lack of resources."
        case kCVReturnInvalidPixelFormat:
            return "\(value): The requested pixelformat is not supported for the CVBuffer type."
        case kCVReturnInvalidSize:
            return "\(value): The requested size (most likely too big) is not supported for the CVBuffer type."
        case kCVReturnInvalidPixelBufferAttributes:
            return "\(value): A CVBuffer cannot be created with the given attributes."
        case kCVReturnPixelBufferNotOpenGLCompatible:
            return "\(value): The Buffer cannot be used with OpenGL as either its size, pixelformat or attributes are not supported by OpenGL."
        case kCVReturnPixelBufferNotMetalCompatible:
            return "\(value): The Buffer cannot be used with Metal as either its size, pixelformat or attributes are not supported by Metal."
        case kCVReturnWouldExceedAllocationThreshold:
            return "\(value): The allocation request failed because it would have exceeded a specified allocation threshold (see kCVPixelBufferPoolAllocationThresholdKey)."
        case kCVReturnPoolAllocationFailed:
            return "\(value): The allocation for the buffer pool failed. Most likely because of lack of resources. Check if your parameters are in range."
        case kCVReturnInvalidPoolAttributes:
            return "\(value): A CVBufferPool cannot be created with the given attributes."
        case kCVReturnRetry:
            return  "\(value): A scan hasn't completely traversed the CVBufferPool due to a concurrent operation. The client can retry the scan."
        default:
            return "\(value): \(fourCharacterCodeString))"
        }
    }
}

internal struct OSStatusValue: Equatable {
    let value: OSStatus
    
    init(_ value: OSStatus) {
        self.value = value
    }
    var fourCharacterCodeString: String {
        return value.fourCharacterCodeString
    }
    
}

internal enum CoreVideoError: Error {
    case failure(CVReturnValue)
}

internal enum CoreMediaError: Error {
    case failure(OSStatus)
}
