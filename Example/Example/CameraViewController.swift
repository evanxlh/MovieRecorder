//
//  CameraViewController.swift
//  Example
//
//  Created by Evan Xie on 2019/5/31.
//

import UIKit
import MovieRecorder

class CameraViewController: RecorderViewController {
    
    var trackDataProvider: AVCameraTrackDataProvider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let audioConfiguration = AudioTrackConfiguration()
        let videoConfiguration = VideoTrackConfiguration(framerate: 30, resolution: CGSize(width: 3840, height: 2160))
        let trackConfiguration = MovieTrackConfiguration.audioAndVideo(audioConfiguration, videoConfiguration)
        trackDataProvider = AVCameraTrackDataProvider(cameraType: .back(.hd4K3840x2160), trackConfiguration: trackConfiguration)
        
        let preview = view as! PreviewView
        recorderDidStated = { [weak self] in
            preview.session = self?.trackDataProvider.session
        }
    }
    
    override func createRecorder() {
        let movieURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MyMovie.mp4")
        recorder = MovieRecorder(outputURL: movieURL, trackDataProvider: trackDataProvider)
        recorder?.errorHandler = { [weak self] error in
            self?.recordButton.isEnabled = true
            self?.recordButton.setTitle("REC", for: .normal)
            self?.recorder = nil
            print("recorder error: \(error)")
        }
    }
}
