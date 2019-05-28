//
//  CMSampleBufferExtension.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/28.
//

import CoreMedia

internal extension CMSampleBuffer {
    
    func modifyTimeInfo(_ newTimestamp: CMTime) throws -> CMSampleBuffer {
        
        var itemCount: CMItemCount = 0
        var timingInfo = Array<CMSampleTimingInfo>(repeating: CMSampleTimingInfo(), count: 3)
        
        CMSampleBufferGetSampleTimingInfoArray(self, entryCount: 3, arrayToFill: &timingInfo, entriesNeededOut: &itemCount)
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
