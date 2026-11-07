import AVFoundation
import Foundation
import XCTest
#if !DICTAI_AUDIO_STANDALONE
@testable import Dict_AI
#endif

class RunnerTests: XCTestCase {
  private var directory: URL!

  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent("dictai-native-audio-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: directory)
  }

  private func path(_ name: String) -> URL { directory.appendingPathComponent(name) }

  /// Synthetic files, bounded generation, no microphone or ScreenCaptureKit.
  private func source(_ name: String, rate: Double, channels: AVAudioChannelCount,
                      seconds: Double, amplitude: Float = 0.25) throws -> URL {
    let url = path(name)
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate,
                              channels: channels, interleaved: false)!
    var settings = format.settings
    settings[AVLinearPCMIsNonInterleaved] = false
    let file = try AVAudioFile(forWriting: url, settings: settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
    var remaining = Int(seconds * rate)
    while remaining > 0 {
      let count = min(remaining, 4096)
      buffer.frameLength = AVAudioFrameCount(count)
      for channel in 0..<Int(channels) {
        for frame in 0..<count { buffer.floatChannelData![channel][frame] = amplitude }
      }
      try file.write(from: buffer)
      remaining -= count
    }
    return url
  }

  private func integer(_ data: Data, _ offset: Int, _ bytes: Int) -> UInt32 {
    (0..<bytes).reduce(UInt32(0)) { $0 | UInt32(data[offset + $1]) << (8 * $1) }
  }

  private func assertPCM(_ output: URL, seconds: Double,
                         file: StaticString = #filePath, line: UInt = #line) throws {
    let handle = try FileHandle(forReadingFrom: output)
    defer { try? handle.close() }
    let header = try XCTUnwrap(try handle.read(upToCount: 44))
    XCTAssertEqual(String(data: header.subdata(in: 0..<4), encoding: .ascii), "RIFF", file: file, line: line)
    XCTAssertEqual(String(data: header.subdata(in: 8..<16), encoding: .ascii), "WAVEfmt ", file: file, line: line)
    XCTAssertEqual(integer(header, 16, 4), 16, file: file, line: line)
    XCTAssertEqual(integer(header, 20, 2), 1, file: file, line: line)
    XCTAssertEqual(integer(header, 22, 2), 1, file: file, line: line)
    XCTAssertEqual(integer(header, 24, 4), 16000, file: file, line: line)
    XCTAssertEqual(integer(header, 28, 4), 32000, file: file, line: line)
    XCTAssertEqual(integer(header, 32, 2), 2, file: file, line: line)
    XCTAssertEqual(integer(header, 34, 2), 16, file: file, line: line)
    XCTAssertEqual(String(data: header.subdata(in: 36..<40), encoding: .ascii), "data", file: file, line: line)
    let size = (try FileManager.default.attributesOfItem(atPath: output.path)[.size] as! NSNumber).uint32Value
    XCTAssertEqual(integer(header, 4, 4) + 8, size, file: file, line: line)
    XCTAssertEqual(integer(header, 40, 4) + 44, size, file: file, line: line)
    XCTAssertEqual(Double(integer(header, 40, 4)) / 32000, seconds,
                   accuracy: 0.002, file: file, line: line)
  }

  func testStereoResamplingProducesCanonicalPCM() throws {
    let input = try source("stereo.wav", rate: 48000, channels: 2, seconds: 0.125)
    let output = path("converted.wav")
    try BoundedWAV.convert(input: input, output: output)
    try assertPCM(output, seconds: 0.125)
    XCTAssertTrue(FileManager.default.fileExists(atPath: input.path))
  }

  func testMixRetainsLongerInputAndClipsSafely() throws {
    let system = try source("system.wav", rate: 48000, channels: 2, seconds: 0.125, amplitude: 1)
    let microphone = try source("microphone.wav", rate: 44100, channels: 1, seconds: 0.25, amplitude: 1)
    let output = path("mixed.wav")
    try BoundedWAV.mix(system: system, microphone: microphone, output: output)
    try assertPCM(output, seconds: 0.25)
    let data = try Data(contentsOf: output)
    XCTAssertEqual(integer(data, 44 + 128 * 2, 2), UInt32(Int16.max))
    XCTAssertTrue(FileManager.default.fileExists(atPath: system.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: microphone.path))
  }

  func testInvalidInputCannotPublishOrLeavePartialFile() throws {
    let input = path("invalid.wav")
    try Data("invalid source".utf8).write(to: input)
    XCTAssertThrowsError(try BoundedWAV.convert(input: input, output: path("output.wav")))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["invalid.wav"])
  }

  func testEmptyInputAndMixAreRejected() throws {
    let empty = try source("empty.wav", rate: 16000, channels: 1, seconds: 0)
    let mic = try source("mic.wav", rate: 16000, channels: 1, seconds: 0.1)
    XCTAssertThrowsError(try BoundedWAV.convert(input: empty, output: path("converted.wav")))
    XCTAssertThrowsError(try BoundedWAV.mix(system: empty, microphone: mic, output: path("mixed.wav")))
    XCTAssertFalse(FileManager.default.fileExists(atPath: path("converted.wav").path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: path("mixed.wav").path))
    XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasSuffix(".partial") })
  }

  func testExistingDestinationAndUserSourceArePreserved() throws {
    let input = try source("source.wav", rate: 16000, channels: 1, seconds: 0.1)
    let output = path("existing.wav")
    let expected = Data("existing user file".utf8)
    try expected.write(to: output)
    XCTAssertThrowsError(try BoundedWAV.convert(input: input, output: output))
    XCTAssertEqual(try Data(contentsOf: output), expected)
    let original = try Data(contentsOf: input)
    XCTAssertThrowsError(try BoundedWAV.mix(system: input, microphone: input, output: input))
    XCTAssertEqual(try Data(contentsOf: input), original)
  }

  func testCancellationPreventsPublicationAndRetainsSource() throws {
    let input = try source("source.wav", rate: 16000, channels: 1, seconds: 0.1)
    let cancellation = BoundedWAV.Cancellation()
    cancellation.cancel()
    XCTAssertThrowsError(try BoundedWAV.convert(input: input, output: path("output.wav"), cancellation: cancellation))
    XCTAssertThrowsError(try BoundedWAV.mix(system: input, microphone: input,
                                          output: path("mixed.wav"), cancellation: cancellation))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["source.wav"])
  }

  func testLongSyntheticConversion() throws {
    // Explicit long run is measured with /usr/bin/time -l by the verifier.
    // The default is fast enough for the ordinary native unit suite.
    let seconds = Double(ProcessInfo.processInfo.environment["DICTAI_AUDIO_TEST_SECONDS"] ?? "2") ?? 2
    let input = try source("long.wav", rate: 48000, channels: 2, seconds: seconds)
    try BoundedWAV.convert(input: input, output: path("long-converted.wav"))
    try assertPCM(path("long-converted.wav"), seconds: seconds)
  }

  func testCancellationDuringConversionRemovesPartialOutput() throws {
    let input = try source("cancel-source.wav", rate: 48000, channels: 2, seconds: 120)
    let output = path("cancel-output.wav")
    let folder = directory!
    let cancellation = BoundedWAV.Cancellation()
    let complete = expectation(description: "conversion cancelled")
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try BoundedWAV.convert(input: input, output: output, cancellation: cancellation)
        XCTFail("Cancelled conversion unexpectedly succeeded")
      } catch BoundedWAV.Failure.cancelled {
        // Expected cooperative cancellation after at least one partial block.
      } catch {
        XCTFail("Expected explicit cancellation, got \(error)")
      }
      complete.fulfill()
    }
    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline {
      if try FileManager.default.contentsOfDirectory(atPath: folder.path).contains(where: { $0.hasSuffix(".partial") }) {
        break
      }
      Thread.sleep(forTimeInterval: 0.001)
    }
    cancellation.cancel()
    wait(for: [complete], timeout: 5)
    XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: input.path))
    XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: folder.path).contains { $0.hasSuffix(".partial") })
  }

  func testFailedStreamStopRetainsHandleAndActuallyRetries() {
    let queue = DispatchQueue(label: "dictai-test-stop-failure")
    var callbacks: [(Error?) -> Void] = []
    let stop = AudioStreamTeardown(queue: queue) { callbacks.append($0) }
    let failure = expectation(description: "first stop failed")
    queue.sync {
      stop.request { XCTAssertNotNil($0); failure.fulfill() }
      callbacks[0](NSError(domain: "synthetic", code: 1))
    }
    wait(for: [failure], timeout: 1)
    let success = expectation(description: "retry confirmed")
    queue.sync {
      XCTAssertFalse(stop.isConfirmed)
      stop.request { XCTAssertNil($0); success.fulfill() }
      XCTAssertEqual(callbacks.count, 2)
      callbacks[1](nil)
    }
    wait(for: [success], timeout: 1)
    queue.sync { XCTAssertTrue(stop.isConfirmed) }
  }

  func testTimedOutStreamStopRetainsHandleAndActuallyRetries() {
    let queue = DispatchQueue(label: "dictai-test-stop-timeout")
    var callbacks: [(Error?) -> Void] = []
    let stop = AudioStreamTeardown(queue: queue, timeout: 0.01) { callbacks.append($0) }
    let timedOut = expectation(description: "stop timeout")
    queue.sync {
      stop.request {
        guard let error = $0, case AudioStreamTeardown.Failure.timeout = error else {
          XCTFail("Expected timeout")
          timedOut.fulfill()
          return
        }
        timedOut.fulfill()
      }
    }
    wait(for: [timedOut], timeout: 1)
    let retried = expectation(description: "retry confirmed")
    queue.sync {
      XCTAssertFalse(stop.isConfirmed)
      stop.request { XCTAssertNil($0); retried.fulfill() }
      XCTAssertEqual(callbacks.count, 2)
      callbacks[1](nil)
    }
    wait(for: [retried], timeout: 1)
  }

  func testDelegateStopConfirmsRetainedTeardownDuringRetry() {
    let queue = DispatchQueue(label: "dictai-test-delegate-stop")
    var callbacks: [(Error?) -> Void] = []
    var confirmations = 0
    var retryReplies = 0
    let stop = AudioStreamTeardown(queue: queue) { callbacks.append($0) }
    let failure = expectation(description: "first stop failed")
    let stopError = NSError(domain: "synthetic", code: 1)
    queue.sync {
      stop.onConfirmed = { confirmations += 1 }
      stop.request { XCTAssertNotNil($0); failure.fulfill() }
      callbacks[0](stopError)
    }
    wait(for: [failure], timeout: 1)
    queue.sync {
      XCTAssertFalse(stop.isConfirmed)
      stop.request { XCTAssertNil($0); retryReplies += 1 }
      XCTAssertEqual(callbacks.count, 2)
      stop.confirmStopped()
      stop.confirmStopped()
      callbacks[0](nil)
      callbacks[1](stopError)
    }
    queue.sync {
      XCTAssertTrue(stop.isConfirmed)
      XCTAssertEqual(confirmations, 1)
      XCTAssertEqual(retryReplies, 1)
      stop.request { XCTAssertNil($0); retryReplies += 1 }
      XCTAssertEqual(retryReplies, 2)
      XCTAssertEqual(callbacks.count, 2)
    }
  }

  func testConcurrentStreamStopsShareNativeAttemptAndCompleteOnce() {
    let queue = DispatchQueue(label: "dictai-test-stop-join")
    var callbacks: [(Error?) -> Void] = []
    var confirmations = 0
    let stop = AudioStreamTeardown(queue: queue) { callbacks.append($0) }
    let first = expectation(description: "first observer")
    let second = expectation(description: "second observer")
    first.assertForOverFulfill = true
    second.assertForOverFulfill = true
    queue.sync {
      stop.onConfirmed = { confirmations += 1 }
      stop.request { XCTAssertNil($0); first.fulfill() }
      stop.request { XCTAssertNil($0); second.fulfill() }
      XCTAssertEqual(callbacks.count, 1)
      callbacks[0](nil)
      callbacks[0](nil)
    }
    wait(for: [first, second], timeout: 1)
    queue.sync { XCTAssertEqual(confirmations, 1) }
  }

  func testLateStreamStopSuccessConfirmsOnlyItsOwnOperation() {
    let queue = DispatchQueue(label: "dictai-test-stop-late")
    var firstCallbacks: [(Error?) -> Void] = []
    var secondCallbacks: [(Error?) -> Void] = []
    let first = AudioStreamTeardown(queue: queue, timeout: 0.01) { firstCallbacks.append($0) }
    let second = AudioStreamTeardown(queue: queue) { secondCallbacks.append($0) }
    let timedOut = expectation(description: "first timeout")
    queue.sync { first.request { XCTAssertNotNil($0); timedOut.fulfill() } }
    wait(for: [timedOut], timeout: 1)
    let lateSuccess = expectation(description: "late original success")
    let otherSuccess = expectation(description: "other stream success")
    lateSuccess.assertForOverFulfill = true
    queue.sync {
      first.request { XCTAssertNil($0); lateSuccess.fulfill() }
      second.request { XCTAssertNil($0); otherSuccess.fulfill() }
      firstCallbacks[0](nil)
    }
    wait(for: [lateSuccess], timeout: 1)
    queue.sync {
      XCTAssertTrue(first.isConfirmed)
      XCTAssertFalse(second.isConfirmed)
      // A stale failed/duplicate callback must not change the other stream.
      firstCallbacks[1](NSError(domain: "synthetic", code: 2))
      firstCallbacks[0](nil)
      secondCallbacks[0](nil)
    }
    wait(for: [otherSuccess], timeout: 1)
  }

}
