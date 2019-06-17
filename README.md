## MovieRecorder
A flexible, versatile movie recorder using Metal for iOS.

### Features

- Support SCNView recorder
- Support system camera recorder
- Support MTLTexture recorder
- Support custom recorder by using `MovieRecorder`.

### How to use?

Below are some example codes, for detailed samples, see `Example` project.

#### SCNViewRecorder Example

```
  var movieURL = URL(fileURLWithPath: NSTemporaryDirectory())
  movieURL = movieURL.appendingPathComponent("myMovie.mp4")
        
  let videoSize = CGSize(width: view.bounds.width * UIScreen.main.nativeScale,
                        height: view.bounds.height * UIScreen.main.nativeScale)
  let configuration = RecorderConfiguration(outputURL: movieURL,
                                       videoFramerate: 60,
                                      videoResulution: videoSize)
  let recorder = SCNViewRecorder(view: view as! SCNView,
                        configuration:configuration)
  recorder.errorHandler = {
  	// Handle error
  }
  
  recorder.startRecording(completionBlock: { 
    // Recorder started successfully.
  })
  
  recorder.stopRecording(completionBlock: { (movieURL) in
    // Recorder finished with saved movie file url.
  }
```

#### AVCameraRecorder Example

```
  let session = AVCameraSession()
  try! session.useAudioDeviceInput()
  try! session.useVideoDeviceInput(for: .back(.hd4K3840x2160))
  session.startRunning()

  var movieURL = URL(fileURLWithPath: NSTemporaryDirectory())
  movieURL = movieURL.appendingPathComponent("myMovie.mp4")
        
  let videoSize = CGSize(width: 3840, height: 2160)
  let configuraiton = RecorderConfiguration(outputURL: movieURL,
		                       videoFramerate: 30,
		                      videoResulution: videoSize, 
		                    enablesAudioTrack: false, 
		                             fileType: .mov)
  let recorder = AVCameraRecorder(session: session, configuration:configuraiton)
  recorder.errorHandler = {
  	  // Handle error
  }
  
  recorder.startRecording(completionBlock: { 
    // Recorder started successfully.
  })
  
  recorder.stopRecording(completionBlock: { (movieURL) in
    // Recorder finished with saved movie file url.
  }

```

#### MTLTexture Example

```
        
  let recorder = MTLTextureRecorder(device: `MTLDevice`, configuration:`configuration`)
  recorder.errorHandler = {
  	// Handle error
  }
  
  recorder.startRecording(completionBlock: { 
    // Recorder started successfully.
  })
  
  recorder.stopRecording(completionBlock: { (movieURL) in
    // Recorder finished with saved movie file url.
  }
  
```

#### Custom Movie Recorder Example

```
  let audioProducer: AudioSampleProducer = ...
  let videoProduer: VideoSampleProducer = ...
  let recorder = MovieRecorder(outputURL: `fileURL`,
                           audioProducer: audioProducer,
                           videoProducer: videoProducer,
                           movieFileType: .mov)
       
  recorder.errorHandler = {
  	// Handle error
  }
                              
  recorder.startRecording(completionBlock: { 
    // Recorder started successfully.
  })
  
  recorder.stopRecording(completionBlock: { (movieURL) in
    // Recorder finished with saved movie file url.
  }
                              
```






