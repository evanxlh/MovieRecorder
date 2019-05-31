//
//  CVPixelBufferExtension.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/30.
//

import CoreVideo
import CoreMedia

extension CVPixelBuffer {
    
    public var formatDescription: CMVideoFormatDescription? {
        var format: CMVideoFormatDescription?
        let result = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: self, formatDescriptionOut: &format)
        guard result == noErr else {
            print("Create video format description failed: \(OSStatusValue(result).description)")
            return nil
        }
        return format
    }
}
