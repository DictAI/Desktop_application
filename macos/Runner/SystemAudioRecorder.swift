import Foundation
import ScreenCaptureKit
import AVFoundation
import FlutterMacOS

/// Flutter Method Channel: "com.dictai/system_audio"
///
/// Methods:
///   requestPermission() -> Bool
///   startRecording(path: String, mode: String) -> void
///   stopRecording() -> void
///   mixWavFiles(systemPath: String, microphonePath: String, outputPath: String) -> void
@available(macOS 13.0, *)
class SystemAudioRecorder: NSObject, SCStreamDelegate, SCStreamOutput {

    static let channelName = "com.dictai/system_audio"

    private let writerQueue = DispatchQueue(label: "com.dictai.systemAudio.writer")
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    private var stream: SCStream?
    private var sysWriter: AVAssetWriter?
    private var sysAudioInput: AVAssetWriterInput?
    private var sysTempPath: String?
    private var finalOutputPath: String?
    private var didReceiveSystemAudio = false
    private var isFinishing = false

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            requestPermission(result: result)
        case "startRecording":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "path is required", details: nil))
                return
            }
            startRecording(path: path, result: result)
        case "stopRecording":
            stopRecording(result: result)
        case "mixWavFiles":
            guard let args = call.arguments as? [String: Any],
                  let systemPath = args["systemPath"] as? String,
                  let microphonePath = args["microphonePath"] as? String,
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "systemPath, microphonePath and outputPath are required", details: nil))
                return
            }
            mixFiles(systemPath: systemPath, microphonePath: microphonePath, outputPath: outputPath, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { _, error in
            DispatchQueue.main.async { result(error == nil) }
        }
    }

    private func startRecording(path: String, result: @escaping FlutterResult) {
        guard stream == nil && sysWriter == nil else {
            result(FlutterError(code: "ALREADY_RECORDING", message: "System audio capture is already running", details: nil))
            return
        }

        finalOutputPath = path
        didReceiveSystemAudio = false
        isFinishing = false

        let dir = URL(fileURLWithPath: path).deletingLastPathComponent().path
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let tempPath = "\(dir)/sys_\(ts).m4a"
        sysTempPath = tempPath

        do {
            try setupSystemWriter(path: tempPath)
        } catch {
            result(FlutterError(code: "WRITER_SETUP_FAILED", message: error.localizedDescription, details: nil))
            return
        }

        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { [weak self] content, error in
            guard let self = self else { return }

            if let error = error {
                self.cleanupSystemWriter(removeTempFile: true)
                DispatchQueue.main.async {
                    result(FlutterError(code: "PERMISSION_DENIED", message: error.localizedDescription, details: nil))
                }
                return
            }

            guard let display = content?.displays.first else {
                self.cleanupSystemWriter(removeTempFile: true)
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_DISPLAY", message: "No display found", details: nil))
                }
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

            let stream = SCStream(filter: filter, configuration: config, delegate: self)

            do {
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.writerQueue)
                stream.startCapture { [weak self] error in
                    guard let self = self else { return }
                    if let error = error {
                        self.cleanupSystemWriter(removeTempFile: true)
                        DispatchQueue.main.async {
                            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
                        }
                        return
                    }
                    self.stream = stream
                    DispatchQueue.main.async { result(nil) }
                }
            } catch {
                self.cleanupSystemWriter(removeTempFile: true)
                DispatchQueue.main.async {
                    result(FlutterError(code: "STREAM_SETUP_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func setupSystemWriter(path: String) throws {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000,
        ]

        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else {
            throw NSError(domain: "SystemAudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot add audio input to writer"])
        }

        writer.add(input)
        sysWriter = writer
        sysAudioInput = input
    }

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard outputType == .audio,
              CMSampleBufferDataIsReady(sampleBuffer),
              let writer = sysWriter,
              let input = sysAudioInput,
              !isFinishing else { return }

        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }

        if writer.status == .writing && input.isReadyForMoreMediaData {
            if input.append(sampleBuffer) {
                didReceiveSystemAudio = true
            } else if let error = writer.error {
                NSLog("[SysAudio] append failed: \(error.localizedDescription)")
            }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        stopRecording(result: nil)
    }

    func stopRecording(result: FlutterResult?) {
        if let stream = stream {
            stream.stopCapture { [weak self] _ in
                guard let self = self else { return }
                self.stream = nil
                self.finishSystemCapture(result: result)
            }
        } else {
            finishSystemCapture(result: result)
        }
    }

    private func finishSystemCapture(result: FlutterResult?) {
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            guard let writer = self.sysWriter,
                  let input = self.sysAudioInput,
                  let tempPath = self.sysTempPath,
                  let outputPath = self.finalOutputPath else {
                DispatchQueue.main.async { result?(nil) }
                return
            }

            self.isFinishing = true

            guard self.didReceiveSystemAudio, writer.status == .writing else {
                writer.cancelWriting()
                self.cleanupSystemWriter(removeTempFile: true)
                DispatchQueue.main.async {
                    result?(FlutterError(code: "NO_AUDIO", message: "No system audio was captured.", details: nil))
                }
                return
            }

            input.markAsFinished()
            writer.finishWriting { [weak self] in
                guard let self = self else { return }

                if writer.status != .completed {
                    let message = writer.error?.localizedDescription ?? "System audio writer did not finish."
                    self.cleanupSystemWriter(removeTempFile: true)
                    DispatchQueue.main.async {
                        result?(FlutterError(code: "WRITE_FAILED", message: message, details: nil))
                    }
                    return
                }

                do {
                    try self.convertAudioFileToWAV(inputPath: tempPath, outputPath: outputPath)
                    self.cleanupSystemWriter(removeTempFile: true)
                    DispatchQueue.main.async { result?(nil) }
                } catch {
                    self.cleanupSystemWriter(removeTempFile: true)
                    DispatchQueue.main.async {
                        result?(FlutterError(code: "CONVERT_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
        }
    }

    private func cleanupSystemWriter(removeTempFile: Bool) {
        let tempPath = sysTempPath
        sysWriter = nil
        sysAudioInput = nil
        sysTempPath = nil
        finalOutputPath = nil
        didReceiveSystemAudio = false
        isFinishing = false

        if removeTempFile, let tempPath = tempPath {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
    }

    private func mixFiles(systemPath: String, microphonePath: String, outputPath: String, result: @escaping FlutterResult) {
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                try self.mixWAV(systemPath: systemPath, microphonePath: microphonePath, outputPath: outputPath)
                DispatchQueue.main.async { result(nil) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "MIX_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func convertAudioFileToWAV(inputPath: String, outputPath: String) throws {
        let buffer = try readConvertedBuffer(path: inputPath)
        try writeWAV(buffer: buffer, outputPath: outputPath)
    }

    private func readConvertedBuffer(path: String) throws -> AVAudioPCMBuffer {
        let inputURL = URL(fileURLWithPath: path)
        let inputFile = try AVAudioFile(forReading: inputURL)
        let inputFormat = inputFile.processingFormat
        let inputFrames = AVAudioFrameCount(inputFile.length)

        guard inputFrames > 0,
              let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: inputFrames) else {
            throw NSError(domain: "SystemAudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio file is empty"])
        }

        try inputFile.read(into: inputBuffer)
        return try convertBufferToTargetFormat(inputBuffer)
    }

    private func convertBufferToTargetFormat(_ inputBuffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let converter = AVAudioConverter(from: inputBuffer.format, to: targetFormat) else {
            throw NSError(domain: "SystemAudioRecorder", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create audio converter"])
        }

        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 2048
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            throw NSError(domain: "SystemAudioRecorder", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot allocate output buffer"])
        }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .endOfStream
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if status == .error {
            throw conversionError ?? NSError(domain: "SystemAudioRecorder", code: 5, userInfo: [NSLocalizedDescriptionKey: "Audio conversion failed"])
        }
        if outputBuffer.frameLength == 0 {
            throw NSError(domain: "SystemAudioRecorder", code: 6, userInfo: [NSLocalizedDescriptionKey: "Converted audio is empty"])
        }

        return outputBuffer
    }

    private func mixWAV(systemPath: String, microphonePath: String, outputPath: String) throws {
        let systemBuffer = try readConvertedBuffer(path: systemPath)
        let microphoneBuffer = try readConvertedBuffer(path: microphonePath)
        let totalFrames = max(systemBuffer.frameLength, microphoneBuffer.frameLength)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: totalFrames),
              let outputData = outputBuffer.floatChannelData?[0] else {
            throw NSError(domain: "SystemAudioRecorder", code: 7, userInfo: [NSLocalizedDescriptionKey: "Cannot allocate mix buffer"])
        }

        outputBuffer.frameLength = totalFrames
        memset(outputData, 0, Int(totalFrames) * MemoryLayout<Float>.size)

        let systemData = systemBuffer.floatChannelData?[0]
        let microphoneData = microphoneBuffer.floatChannelData?[0]

        for i in 0..<Int(totalFrames) {
            let sys = i < Int(systemBuffer.frameLength) ? (systemData?[i] ?? 0) : 0
            let mic = i < Int(microphoneBuffer.frameLength) ? (microphoneData?[i] ?? 0) : 0
            outputData[i] = max(-1, min(1, (sys * 0.8) + (mic * 0.8)))
        }

        try writeWAV(buffer: outputBuffer, outputPath: outputPath)
    }

    private func writeWAV(buffer: AVAudioPCMBuffer, outputPath: String) throws {
        let outputURL = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: outputURL)
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: targetFormat.settings)
        try outputFile.write(from: buffer)
    }
}
