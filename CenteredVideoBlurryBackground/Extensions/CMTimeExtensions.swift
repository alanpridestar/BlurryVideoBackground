//
//  CMTimeExtensions.swift
//  VideoBorders
//
//  Created by macmini7 on 7/29/19.
//  Copyright © 2019 macmini7. All rights reserved.
//

import CoreMedia

// MARK: Initialization
public extension CMTime {
	init(value: Int64, _ timescale: Int = 1) {
		self = CMTimeMake(value: value, timescale: Int32(timescale))
	}
	init(value: Int64, _ timescale: Int32 = 1) {
		self = CMTimeMake(value: value, timescale: timescale)
	}
	init(seconds: Float64, preferredTimeScale: Int32 = 1_000_000_000) {
		self = CMTimeMakeWithSeconds(seconds, preferredTimescale: preferredTimeScale)
	}
	init(seconds: Float, preferredTimeScale: Int32 = 1_000_000_000) {
		self = CMTime(seconds: Float64(seconds), preferredTimeScale: preferredTimeScale)
	}
}

// MARK: - Arithmetic Protocol

// MARK: Multiply
func * (time: CMTime, multiplier: Int32) -> CMTime {
	return CMTimeMultiply(time, multiplier: multiplier)
}
func * (multiplier: Int32, time: CMTime) -> CMTime {
	return CMTimeMultiply(time, multiplier: multiplier)
}
func * (time: CMTime, multiplier: Float64) -> CMTime {
	return CMTimeMultiplyByFloat64(time, multiplier: multiplier)
}
func * (time: CMTime, multiplier: Float) -> CMTime {
	return CMTimeMultiplyByFloat64(time, multiplier: Float64(multiplier))
}
func * (multiplier: Float64, time: CMTime) -> CMTime {
	return time * multiplier
}
func * (multiplier: Float, time: CMTime) -> CMTime {
	return time * multiplier
}
func *= ( time: inout CMTime, multiplier: Int32) -> CMTime {
	time = time * multiplier
	return time
}
func *= ( time: inout CMTime, multiplier: Float64) -> CMTime {
	time = time * multiplier
	return time
}
func *= ( time: inout CMTime, multiplier: Float) -> CMTime {
	time = time * multiplier
	return time
}

// MARK: Divide
func / (time: CMTime, divisor: Int32) -> CMTime {
	return CMTimeMultiplyByRatio(time, multiplier: 1, divisor: divisor)
}
func /= ( time: inout CMTime, divisor: Int32) -> CMTime {
	time = time / divisor
	return time
}

public func == (time1: CMTime, time2: CMTime) -> Bool {
	return CMTimeCompare(time1, time2) == 0
}
public func < (time1: CMTime, time2: CMTime) -> Bool {
	return CMTimeCompare(time1, time2) < 0
}

extension CMTime {
	var f: Float {
		return Float(self.f64)
	}
	var f64: Float64 {
		return CMTimeGetSeconds(self)
	}
}
