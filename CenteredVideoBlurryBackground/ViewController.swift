//
//  ViewController.swift
//  CenteredVideoBlurryBackground
//
//  Created by macmini7 on 10/24/19.
//  Copyright © 2019 macmini7. All rights reserved.
//

import UIKit
import AVKit

class ViewController: UIViewController {

	@IBOutlet weak var progressValueLabel: UILabel!

	@IBOutlet var buttons: [UIButton]!

	let downloadedMp4Path = Bundle.main.path(forResource: "Downloaded", ofType: "mp4")!
	var downloadedMp4Url: URL {
		return URL(fileURLWithPath: downloadedMp4Path)
	}

	let cameraRecordedMovPath = Bundle.main.path(forResource: "CameraRecorded", ofType: "MOV")!
	var cameraRecordedMovUrl: URL {
		return URL(fileURLWithPath: cameraRecordedMovPath)
	}

	let downloadedMovPath = Bundle.main.path(forResource: "DownloadedMov", ofType: "mov")!
	var downloadedMovUrl: URL {
		return URL(fileURLWithPath: downloadedMovPath)
	}

	func useBlurredManager(url: URL) {
		let manager = BlurredBackgroundVideoManager.shared
		manager.delegate = self
		disableAllButtons()
		manager.createVideoOutput(url: url, size: CGSize(width: 1080, height: 720), scale: 0.5) { (outputUrl, error) in
			self.enableAllButtons()
			if let error = error {
				print(error)
			} else if let outputUrl = outputUrl {
				self.playVideo(url: outputUrl)
			}
		}
	}

	func playVideo(url: URL) {
		DispatchQueue.main.async {
			let controller = AVPlayerViewController()
			controller.player = AVPlayer(url: url)
			self.present(controller, animated: true) {
				controller.player?.play()
			}
		}
	}

	//MARK: - UI
	fileprivate func disableAllButtons() {
		DispatchQueue.main.async {
			self.buttons.forEach { (b) in
				b.isEnabled = false
			}
		}
	}

	fileprivate func enableAllButtons() {
		DispatchQueue.main.async {
			self.buttons.forEach { (b) in
				b.isEnabled = true
			}
		}
	}

	//MARK: - Button Presses
	@IBAction func processMp4(_ sender: Any) {
		useBlurredManager(url: downloadedMp4Url)
	}

	@IBAction func processCameraRecordedVideo(_ sender: Any) {
		useBlurredManager(url: cameraRecordedMovUrl)
	}

	@IBAction func processDownloadedMovVideo(_ sender: Any) {
		useBlurredManager(url: downloadedMovUrl)
	}
}

extension ViewController: BlurredBackgroundVideoManagerDelegate {
	func progressUpdated(_ progress: Float) {
		print(progress)
		let roundedProgress = progress.rounded(toPlaces: 2)
		DispatchQueue.main.async {
			self.progressValueLabel.text = "\(roundedProgress * 100) %"
		}
	}
}

extension Float {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> Float {
        let divisor = pow(10.0, Float(places))
        return (self * divisor).rounded() / divisor
    }
}
