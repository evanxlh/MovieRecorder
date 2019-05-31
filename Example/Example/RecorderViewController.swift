//
//  RecorderViewController.swift
//  Example
//
//  Created by Evan Xie on 2019/5/31.
//

import UIKit
import AVKit
import MovieRecorder

class RecorderViewController: UIViewController {
    
    deinit {
        print("\(self) deinit")
    }
    
    var recorder: MovieRecorder?
    
    lazy var recordButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.red
        button.borderColor = UIColor.white
        button.borderWidth = 2
        button.shadowRadius = 2
        button.shadowOpacity = 0.5
        button.cornerRadius = 35
        button.setTitle("REC", for: .normal)
        return button
    }()
    
    var recorderDidStated: (() -> Void)?
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if recordButton.superview == nil {
            addRecordButton()
        }
    }
    
    private func addRecordButton() {
        
        recordButton.addTarget(self, action: #selector(recorderButtonTapped), for: .touchUpInside)
        view.addSubview(recordButton)
        
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = NSLayoutConstraint(item: recordButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 70)
        let heightConstraint = NSLayoutConstraint(item: recordButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 70)
        recordButton.addConstraints([widthConstraint, heightConstraint])
        
        let centerX = NSLayoutConstraint(item: recordButton, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0)
        let bottomY = NSLayoutConstraint(item: recordButton, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: -100)
        view.addConstraints([centerX, bottomY])
    }
    
    @objc private func recorderButtonTapped(_ button: UIButton) {
        if recorder == nil {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    func createRecorder() {
        
    }
    
    func startRecording() {
        
        let button = recordButton
        button.isEnabled = false
        
        createRecorder()
        recorder?.startRecording(completionBlock: { [weak self] in
            button.setTitle("STOP", for: .normal)
            button.isEnabled = true
            self?.recorderDidStated?()
        })
    }
    
    func stopRecording() {
        
        let button = recordButton
        button.isEnabled = false
        
        recorder?.stopRecording(completionBlock: { [weak self] (movieURL) in
            button.isEnabled = true
            button.setTitle("REC", for: .normal)
            let playerViewController = AVPlayerViewController()
            let player = AVPlayer(url: movieURL)
            playerViewController.player = player
            self?.present(playerViewController, animated: true, completion: {
                player.play()
            })
            
            self?.recorder = nil
        })
    }
}
