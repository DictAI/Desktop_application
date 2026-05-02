import Foundation
import ScreenCaptureKit
import AVFoundation
import FlutterMacOS

/// Flutter Method Channel: "com.dictai/system_audio"
///
/// Methods:
///   requestPermission() → Bool
///   startRecording(path: String) → void
///   stopRecording() → void
///
/// The channel is registered in AppDelegate.swift.
@available(macOS 13.0, *)
class SystemAudioRecorder: NSObject, SCStreamDelegate, SCStreamOutput {

    static let channelName = "com.dictai/system_audio"

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var outputPath: String?
    private var isWriting = false
    private var pendingResult: FlutterResult?

    // MARK: – Flutter method handler

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            requestPermission(result: result)
        case "startRecording":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "BAD_ARGS",
                                    message: "path is required",
                                    details: nil))
                return
            }
            startRecording(path: path, result: result)
        case "stopRecording":
            stopRecording(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: – Permission

    private func requestPermission(result: @escaping FlutterResult) {
        SCShareableContent.getExcludingDesktopWindows(false,
                                                     onScreenWindowsOnly: false) { _, error in
            DispatchQueue.main.async {
                result(error == nil)
            }
        }
    }

    // MARK: – Start

    private func startRecording(path: String, result: @escaping FlutterResult) {
        outputPath = path

        SCShareableContent.getExcludingDesktopWindows(false,
                                                     onScreenWindowsOnly: false) { [weak self] content, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    result(FlutterError(code: "PERMISSION_DENIED",
                                        message: error.localizedDescription,
                                        details: nil))
                }
                return
            }

            guard let display = content?.displays.first else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_DISPLAY",
                                        message: "No display found",
                                        details: nil))
                }
                return
            }

            // Audio-only — capture the entire display but exclude visuals
            let filter = SCContentFilter(display: display,
                                         excludingWindows: [])

            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true  // don't capture our own app
            // Minimal video config — we only care about audio
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 fps — irrelevant

            self.setupAssetWriter(path: path)

            let stream = SCStream(filter: filter,
                                  configuration: config,
                                  delegate: self)

            do {
                try stream.addStreamOutput(self,
                                           type: .audio,
                                           sampleHandlerQueue: .global(qos: .userInitiated))
                stream.startCapture { [weak self] error in
                    DispatchQueue.main.async {
                        if let error = error {
                            result(FlutterError(code: "START_FAILED",
                                                message: error.localizedDescription,
                                                details: nil))
                        } else {
                            self?.stream = stream
                            result(nil)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "STREAM_SETUP_FAILED",
                                        message: error.localizedDescription,
                                        details: nil))
                }
            }
        }
    }

    // MARK: – Asset Writer setup

    private func setupAssetWriter(path: String) {
        let url = URL(fileURLWithPath: path)
        guard let writer = try? AVAssetWriter(outputURL: url,
                                              fileType: .m4a) else { return }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000,
        ]

        let input = AVAssetWriterInput(mediaType: .audio,
                                       outputSettings: settings)
        input.expectsMediaDataInRealTime = true

        writer.add(input)
        assetWriter = writer
        audioInput = input
    }

    // MARK: – SCStreamOutput

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard outputType == .audio,
              let writer = assetWriter,
              let input = audioInput,
              CMSampleBufferDataIsReady(sampleBuffer) else { return }

        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            isWriting = true
        }

        if writer.status == .writing && input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }

    // MARK: – SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        stopRecording(result: nil)
    }

    // MARK: – Stop

    func stopRecording(result: FlutterResult?) {
        guard let stream = stream else {
            result?(nil)
            return
        }

        stream.stopCapture { [weak self] _ in
            guard let self = self else { return }
            self.stream = nil

            guard let writer = self.assetWriter, self.isWriting else {
                DispatchQueue.main.async { result?(nil) }
                return
            }

            self.audioInput?.markAsFinished()
            writer.finishWriting {
                DispatchQueue.main.async {
                    result?(nil)
                }
            }
            self.assetWriter = nil
            self.audioInput = nil
            self.isWriting = false
        }
    }
}
