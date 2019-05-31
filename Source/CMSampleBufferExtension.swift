//
//  CMSampleBufferExtension.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/28.
//

import CoreMedia

internal extension CMSampleBuffer {
    
    func adjustTimeInfo(_ newTimestamp: CMTime) throws -> CMSampleBuffer {
        
        var itemCount: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &itemCount)
        var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: itemCount)
        
        for index in 0..<itemCount {
            timingInfo[index].decodeTimeStamp = newTimestamp
            timingInfo[index].presentationTimeStamp = newTimestamp
        }
        
        var syncedSample: CMSampleBuffer?
        let result = CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: self,
                                sampleTimingEntryCount: itemCount, sampleTimingArray: timingInfo, sampleBufferOut: &syncedSample)
        guard result == noErr else {
            throw CoreMediaError.failure(result)
        }
        
        return syncedSample!
    }
}
