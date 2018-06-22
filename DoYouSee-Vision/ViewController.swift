//
//  ViewController.swift
//  DoYouSee-Vision
//
//  Created by Helen Olhausen on 11/29/17.
//  Copyright © 2017 Helen Olhausen. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    let resultLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = ""
        label.numberOfLines = 0
        label.font = UIFont.boldSystemFont(ofSize: 18)
        return label
    }()
    
    lazy var classificationRequest: VNCoreMLRequest = {
        // load the Resnet50 ML model through its generated class and create a Vision request for it.
        do {
            let resNet50Model = try VNCoreMLModel(for: Resnet50().model)
            
            // set up the request using our vision model
            let classificationRequest = VNCoreMLRequest(model: resNet50Model, completionHandler: self.handleClassifications)
            classificationRequest.imageCropAndScaleOption = .centerCrop
            
            return classificationRequest
            
        } catch {
            fatalError("can't load model: \(error)")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoCaptureSession()
        
        // setup the label
        view.addSubview(resultLabel)
        resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32).isActive = true
        resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32).isActive = true
        resultLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50).isActive = true
    }
    
    func setupVideoCaptureSession() {
        
        // create a video capture session
        let videoCaptureSession = AVCaptureSession()
        
        // get the default video camera
        guard let camera = AVCaptureDevice.default(for: .video) else {
            fatalError("No video camera available")
        }
        
        // create the capture input with the camera detected and wire up to the video capture session
        do {
            videoCaptureSession.addInput(try AVCaptureDeviceInput(device: camera))
        } catch {
            print(error.localizedDescription)
        }
        
        videoCaptureSession.sessionPreset = .high
        
        // setup video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        // wire up the video output to the video capture session
        videoCaptureSession.addOutput(videoOutput)
        
        // make sure to setup your project to only portrait! specify portrait mode for video output
        let connection = videoOutput.connection(with: .video)
        connection?.videoOrientation = .portrait
        
        // add the preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: videoCaptureSession)
        previewLayer.frame = view.frame
        view.layer.addSublayer(previewLayer)
        
        // Start the session
        videoCaptureSession.startRunning()
    }
    
    
    func handleClassifications(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNClassificationObservation]  else {
            fatalError("unexpected result type from VNCoreMLRequest")
        }
        guard let best = observations.first else {
            fatalError("can't get best result")
        }
        
        DispatchQueue.main.async {
            self.resultLabel.text = "I'm seeing a \"\(best.identifier)\" I'm \(best.confidence * 100)% confident 🤞🏼"
        }
        
    }
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // called everytime a frame is captured
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        connection.videoOrientation = .portrait
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .upMirrored)
        do {
            try imageRequestHandler.perform([classificationRequest])
            
        } catch {
            print(error)
        }
    }
    
}
