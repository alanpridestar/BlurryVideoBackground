//
//  AVFoundationExtensions.swift
//  VideoBorders
//
//  Created by macmini7 on 9/25/19.
//  Copyright © 2019 macmini7. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

internal func RadiansToDegree(radians: CGFloat) -> CGFloat {
	return (radians * 180.0)/(CGFloat)(Double.pi)
}

extension AVAssetTrack{

	func getVideoOrientation() -> UIImage.Orientation {
		let txf = preferredTransform
		let videoAngleInDegree = RadiansToDegree(radians: atan2(txf.b, txf.a))

		var orientation = UIImage.Orientation.up

		switch (Int)(videoAngleInDegree) {
		case 0:
			orientation = .right
			break
		case 90:
			orientation = .up
			break
		case 180:
			orientation = .left
			break
		case -90:
			orientation = .down
			break
		default:
			break
		}

		return orientation
	}

	func assetSize() -> CGSize {
		let size = naturalSize.applying(preferredTransform)
		return CGSize(width: abs(size.width), height: abs(size.height))
	}
}

extension URL {
	func getMediaDuration() -> Double {
		let asset = AVURLAsset(url: self)
		let duration = asset.duration
		return CMTimeGetSeconds(duration)
	}

	func getVideoResolution() -> CGSize? {
		guard let track = AVAsset(url: self).tracks(withMediaType: .video).first else { return nil }
		let size = __CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform)
		return CGSize(width: abs(size.width), height: abs(size.height))
	}

	func getVideoAspectRatio() -> Float {
		guard let res = getVideoResolution() else { return 0 }
		return Float(res.width / res.height)
	}
}
