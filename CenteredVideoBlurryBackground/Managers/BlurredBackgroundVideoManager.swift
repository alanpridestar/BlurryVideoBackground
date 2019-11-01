//
//  BlurredBackgroundVideoManager.swift
//  VideoBorders
//
//  Created by macmini7 on 9/25/19.
//  Copyright © 2019 macmini7. All rights reserved.
//

import Foundation
import AVFoundation
import Photos
import UIKit

protocol BlurredBackgroundVideoManagerDelegate: class {
	func progressUpdated(_ progress: Float)
}

class BlurredBackgroundVideoManager {

	typealias BlurredBackgroundManagerCompletion = ((URL?, Error?) -> ())

	public static let shared = BlurredBackgroundVideoManager()
	weak var delegate: BlurredBackgroundVideoManagerDelegate?

	fileprivate var displayLink: CADisplayLink?
	fileprivate var currentStage = 0
	fileprivate var currentExporter: AVAssetExportSession!


	func videoOutputUrl(filename: String, filetype: String = "mov") -> URL {
		let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/\(filename).\(filetype)"
		return URL(fileURLWithPath: path)
	}

	func createVideoOutput(url: URL, size: CGSize, scale: CGFloat, completion: @escaping BlurredBackgroundManagerCompletion) {

		let asset = AVURLAsset(url: url)
		self.size = size
//		saveVideoInGallery(url: url) //Use these to test
		self.setupVideo(asset, inArea: size) { (outputUrl, error) in
			if let outputUrl = outputUrl {
//				self.saveVideoInGallery(url: outputUrl)
				let outputAsset = AVURLAsset(url: outputUrl)
				self.addBlurEffect(toVideo: outputAsset, size: size) { (blurUrl, error) in
					if let error = error {
						completion(nil, error)
					} else if let blurUrl = blurUrl {
						let blurAsset = AVURLAsset(url: blurUrl)
//						self.saveVideoInGallery(url: blurUrl)
						self.addAllVideosAtCenterOfBlur(asset: asset, blurVideo: blurAsset, scale: scale, completion: { (finalUrl, error) in
							if let finalUrl = finalUrl {
//								self.saveVideoInGallery(url: finalUrl)
								completion(finalUrl, nil)
							} else if let error = error {
								completion(nil, error)
							}
						})
					}
				}
			} else if let error = error {
				completion(nil, error)
			}
		}
	}

	var size = CGSize(width: 600, height: 600)

	fileprivate func setupVideo(_ asset: AVURLAsset, inArea area: CGSize, completion: @escaping BlurredBackgroundManagerCompletion) {

		let mixComposition = AVMutableComposition()

		var instructionLayers : Array<AVMutableVideoCompositionLayerInstruction> = []

		let track = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)

		let timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
		if let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first {

			try? track?.insertTimeRange(timeRange, of: videoTrack, at: mixComposition.duration)

			let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track!)

			let properties = scaleAndPositionInAspectFillMode(forTrack: videoTrack, inArea: area)
//			let properties = scaleAndPositionInAspectFitMode(forTrack: videoTrack, inArea: area, scale: 1.0)

			let videoOrientation: UIImage.Orientation = videoTrack.getVideoOrientation()
			let assetSize = videoTrack.assetSize()

			let preferredTransform = getPreferredTransform(videoOrientation: videoOrientation, assetSize: assetSize, defaultTransform: asset.preferredTransform, properties: properties)

			layerInstruction.setTransform(preferredTransform, at: .zero)

			instructionLayers.append(layerInstruction)
		}

		if let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
			let aTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
			try? aTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
		}


		let mainInstruction = AVMutableVideoCompositionInstruction()
		mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: mixComposition.duration)
		mainInstruction.layerInstructions = instructionLayers

		let mainCompositionInst = AVMutableVideoComposition()
		mainCompositionInst.instructions = [mainInstruction]
		mainCompositionInst.frameDuration = CMTimeMake(value: 1, timescale: 30)
		mainCompositionInst.renderSize = area

		let url = self.videoOutputUrl(filename: "center")
		try? FileManager.default.removeItem(at: url)

		performExport(composition: mixComposition, instructions: mainCompositionInst, stage: 0, outputUrl: url) { (error) in
			if let error = error {
				completion(nil, error)
			} else {
				completion(url, nil)
			}
		}
	}

	fileprivate func addBlurEffect(toVideo asset:AVURLAsset, size: CGSize, completion: @escaping BlurredBackgroundManagerCompletion) {

		let filter = CIFilter(name: "CIGaussianBlur")

		let composition = AVMutableVideoComposition(asset: asset) { (request) in
			let source: CIImage? = request.sourceImage

			filter?.setValue(source, forKey: kCIInputImageKey)
			filter?.setValue(10.0, forKey: kCIInputRadiusKey)

			let output: CIImage? = filter?.outputImage?.cropped(to: request.sourceImage.extent)
			if let anOutput = output {
				request.finish(with: anOutput, context: nil)
			}
		}

		let url = self.videoOutputUrl(filename: "blurred")
		try? FileManager.default.removeItem(at: url)

		composition.renderSize = size

		let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
		exporter?.videoComposition = composition
		exporter?.outputFileType = .mov
		exporter?.outputURL = url


		// Update for the timer
		currentStage = 1

		if let exporter = exporter {
			currentExporter = exporter
		}

		exporter?.exportAsynchronously(completionHandler: {
			if let anError = exporter?.error {
				self.invalidateDisplayLink()
				completion(nil, anError)
			}
			else if exporter?.status == AVAssetExportSession.Status.completed {
				completion(url, nil)
			}
		})

	}

	fileprivate func addAllVideosAtCenterOfBlur(asset: AVURLAsset, blurVideo: AVURLAsset, scale: CGFloat, completion: @escaping BlurredBackgroundManagerCompletion) {

		let mixComposition = AVMutableComposition()

		var instructionLayers : Array<AVMutableVideoCompositionLayerInstruction> = []

		let blurVideoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)

		if let videoTrack = blurVideo.tracks(withMediaType: AVMediaType.video).first {
			let timeRange = CMTimeRange(start: .zero, duration: blurVideo.duration)
			try? blurVideoTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
		}

		let timeRange = CMTimeRange(start: .zero, duration: asset.duration)

		let track = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)

		// Now we set the length of the track equal to the length of the asset and add the asset to out newly created track at .zero for first track and lastAssetTime for current track so video plays from the start of the track to end.
		if let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first {

			/// Hide time for this video's layer
//			let opacityStartTime: CMTime = CMTimeMakeWithSeconds(0, preferredTimescale: asset.duration.timescale)

			/// Adding video track
			try? track?.insertTimeRange(timeRange, of: videoTrack, at: .zero)

			/// Layer instrcution
			let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track!)

			/// Add logic for aspectFit in given area
			let properties = scaleAndPositionInAspectFitMode(forTrack: videoTrack, inArea: size, scale: scale)

//			 Checking for orientation
			let videoOrientation = videoTrack.getVideoOrientation()
			let assetSize = videoTrack.assetSize()

			let preferredTransform = getPreferredTransform(videoOrientation: videoOrientation, assetSize: assetSize, defaultTransform: asset.preferredTransform, properties: properties)

			layerInstruction.setTransform(preferredTransform, at: .zero)

			instructionLayers.append(layerInstruction)
		}

		/// Adding audio
		if let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
			let aTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
			try? aTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
		}


		/// Blur layer instruction
		let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: blurVideoTrack!)
		instructionLayers.append(layerInstruction)

		let mainInstruction = AVMutableVideoCompositionInstruction()
		mainInstruction.timeRange = timeRange
		mainInstruction.layerInstructions = instructionLayers

		let mainCompositionInst = AVMutableVideoComposition()
		mainCompositionInst.instructions = [mainInstruction]
		mainCompositionInst.frameDuration = CMTimeMake(value: 1, timescale: 30)
		mainCompositionInst.renderSize = size

		//let url = URL(fileURLWithPath: "/Users/enacteservices/Desktop/final_video.mov")
		let url = self.videoOutputUrl(filename: "finalBlurred")
		try? FileManager.default.removeItem(at: url)

		performExport(composition: mixComposition, instructions: mainCompositionInst, stage: 2, outputUrl: url) { (error) in
			if let error = error {
				completion(nil, error)
			} else {
				completion(url, nil)
			}
		}
	}

	fileprivate func performExport(composition: AVMutableComposition, instructions: AVMutableVideoComposition?, stage: Int, outputUrl: URL, completion: @escaping (Error?) -> ()) {
		let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
		exporter?.outputURL = outputUrl
		exporter?.outputFileType = .mov
		if let instructions = instructions {
			exporter?.videoComposition = instructions
		}
		exporter?.shouldOptimizeForNetworkUse = true

		currentExporter = exporter
		currentStage = stage

		if displayLink == nil {
			createDisplayLink()
		}

		exporter?.exportAsynchronously {
			if stage == 2 {
				self.invalidateDisplayLink()
			}

			if let anError = exporter?.error {
				self.invalidateDisplayLink()
				completion(anError)
			} else {
				completion(nil)
			}
		}
	}

	//MARK: - Save Video
	func saveVideoInGallery(url: URL) {
		PHPhotoLibrary.shared().performChanges({
			PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
		})
	}


	//MARK: - Display Link
	func createDisplayLink() {
		DispatchQueue.main.async {
			self.displayLink = CADisplayLink(target: self, selector: #selector(self.updateProgress))
			self.displayLink!.add(to: .current, forMode: .common)
		}
	}

	func invalidateDisplayLink() {
		DispatchQueue.main.async {
			self.displayLink?.remove(from: .current, forMode: .common)
			self.displayLink = nil
		}
	}

	fileprivate func scaleAndPositionInAspectFillMode(forTrack track:AVAssetTrack, inArea area: CGSize, scale: CGFloat = 1.0) -> Properties {
		let assetSize = track.assetSize()
		let aspectFillSize  = CGSize.aspectFill(videoSize: assetSize, boundingSize: area, scale: scale)
		let aspectFillScale = CGSize(width: aspectFillSize.width/assetSize.width, height: aspectFillSize.height/assetSize.height)
		let position = CGPoint(x: ((area.width - aspectFillSize.width) * 0.5).rounded(), y: ((area.height - aspectFillSize.height) * 0.5).rounded())
		return Properties(scale: aspectFillScale, position: position)
	}

	fileprivate func scaleAndPositionInAspectFitMode(forTrack track:AVAssetTrack, inArea area: CGSize, scale: CGFloat) -> Properties {
		let assetSize = track.assetSize()
		let aspectFitSize  = CGSize.aspectFit(videoSize: assetSize, boundingSize: area, scale: scale)
		let aspectFitScale = CGSize(width: aspectFitSize.width/assetSize.width, height: aspectFitSize.height/assetSize.height)
		let position = CGPoint(x: ((area.width - aspectFitSize.width)/2.0).rounded(), y: ((area.height - aspectFitSize.height)/2.0).rounded())
		return Properties(scale: aspectFitScale, position: position)
	}

	@objc fileprivate func updateProgress() {
		let progress = currentExporter.progress / 3 + Float(currentStage)/3
		delegate?.progressUpdated(progress)
	}
}

fileprivate class Properties {
	let scale: CGSize
	let position: CGPoint

	init(scale: CGSize, position: CGPoint) {
		self.scale = scale
		self.position = position
	}
}

//MARK: - Dealing with orientation stuff
extension BlurredBackgroundVideoManager {

	fileprivate func getPreferredTransform(videoOrientation: UIImage.Orientation, assetSize: CGSize, defaultTransform: CGAffineTransform, properties: Properties) -> CGAffineTransform {
		switch videoOrientation {
		case .down:
			return handleDownOrientation(assetSize: assetSize, defaultTransform: defaultTransform, properties: properties)
		case .left:
			return handleLeftOrientation(assetSize: assetSize, defaultTransform: defaultTransform, properties: properties)
		case .right:
			return handleRightOrientation(properties: properties)
		case .up:
			return handleUpOrientation(assetSize: assetSize, defaultTransform: defaultTransform, properties: properties)
		default:
			return handleOtherCases(assetSize: assetSize, defaultTransform: defaultTransform, properties: properties)
		}
	}

	fileprivate func handleDownOrientation(assetSize: CGSize, defaultTransform: CGAffineTransform, properties: Properties) -> CGAffineTransform {
		let rotateTransform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi/2.0))

		// Scale
		let scaleTransform = CGAffineTransform(scaleX: properties.scale.width, y: properties.scale.height)

		// Translate
		var ytranslation: CGFloat = assetSize.height
		var xtranslation: CGFloat = 0
		if properties.position.y == 0 {
			xtranslation = -(assetSize.width - ((size.width/size.height) * assetSize.height))/2.0
		}
		else {
			ytranslation = assetSize.height - (assetSize.height - ((size.height/size.width) * assetSize.width))/2.0
		}
		let translationTransform = CGAffineTransform(translationX: xtranslation, y: ytranslation)

		// Final transformation - Concatination
		let finalTransform = defaultTransform.concatenating(rotateTransform).concatenating(translationTransform).concatenating(scaleTransform)
		return finalTransform
	}

	fileprivate func handleLeftOrientation(assetSize: CGSize, defaultTransform: CGAffineTransform, properties: Properties) -> CGAffineTransform {

		let rotateTransform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi))

		// Scale
		let scaleTransform = CGAffineTransform(scaleX: properties.scale.width, y: properties.scale.height)

		// Translate
		var ytranslation: CGFloat = assetSize.height
		var xtranslation: CGFloat = assetSize.width
		if properties.position.y == 0 {
			xtranslation = assetSize.width - (assetSize.width - ((size.width/size.height) * assetSize.height))/2.0
		} else {
			ytranslation = assetSize.height - (assetSize.height - ((size.height/size.width) * assetSize.width))/2.0
		}
		let translationTransform = CGAffineTransform(translationX: xtranslation, y: ytranslation)

		// Final transformation - Concatination
		let finalTransform = defaultTransform.concatenating(rotateTransform).concatenating(translationTransform).concatenating(scaleTransform)

		return finalTransform
	}

	fileprivate func handleRightOrientation(properties: Properties) -> CGAffineTransform  {
		let scaleTransform = CGAffineTransform(scaleX: properties.scale.width, y: properties.scale.height)

		// Translate
		let translationTransform = CGAffineTransform(translationX: properties.position.x, y: properties.position.y)

		let finalTransform  = scaleTransform.concatenating(translationTransform)
		return finalTransform
	}

	fileprivate func handleUpOrientation(assetSize: CGSize, defaultTransform: CGAffineTransform, properties: Properties) -> CGAffineTransform {

		return handleOtherCases(assetSize: assetSize, defaultTransform: defaultTransform, properties: properties)
	}

	fileprivate func handleOtherCases(assetSize: CGSize, defaultTransform: CGAffineTransform, properties: Properties) -> CGAffineTransform {
        	let rotateTransform = CGAffineTransform(rotationAngle: CGFloat(Double.pi/2.0))
        	let scaleTransform = CGAffineTransform(scaleX: properties.scale.width, y: properties.scale.height)

        	let ytranslation: CGFloat = ( self.size.height - ( assetSize.height * properties.scale.height ) ) / 2
        	let xtranslation: CGFloat = ( assetSize.width * properties.scale.width ) + ( self.size.width - ( assetSize.width * properties.scale.width ) ) / 2
        	let translationTransform = CGAffineTransform(translationX: xtranslation, y: ytranslation)

        	let finalTransform = defaultTransform.concatenating(scaleTransform).concatenating(rotateTransform).concatenating(translationTransform)
        	return finalTransform
    	}
}
