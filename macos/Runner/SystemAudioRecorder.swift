import AVFoundation
import FlutterMacOS
import Foundation
import ScreenCaptureKit

/// Flutter MethodChannel com.dictai/system_audio. Capture state, writer and
/// replies belong to captureQueue. Offline work never waits on the main queue.
@available(macOS 13.0, *)
final class SystemAudioRecorder: NSObject, SCStreamDelegate, SCStreamOutput {
    static let channelName = "com.dictai/system_audio"

    private enum Phase {
        case starting, recording, stopping, finishing, converting
    }

    private final class Reply {
        private var callback: FlutterResult?

        init(_ callback: @escaping FlutterResult) { self.callback = callback }

        func send(_ value: Any?) {
            guard let callback else { return }
            self.callback = nil
            DispatchQueue.main.async { callback(value) }
        }
    }

    private final class Capture {
        let output: URL
        let scratch: URL
        let writer: AVAssetWriter
        let input: AVAssetWriterInput
        var phase: Phase = .starting
        var stream: SCStream?
        var reply: Reply?
        var failure: FlutterError?
        var firstTimestamp: CMTime?
        var didWrite = false
        let cancellation = BoundedWAV.Cancellation()

        init(output: URL, reply: Reply) throws {
            self.output = output
            self.reply = reply
            scratch = output.deletingLastPathComponent().appendingPathComponent(".dictai-system-\(UUID()).m4a")
            writer = try AVAssetWriter(outputURL: scratch, fileType: .m4a)
            input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000,
            ])
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else {
                try? FileManager.default.removeItem(at: scratch)
                throw BoundedWAV.Failure.conversion
            }
            writer.add(input)
        }
    }

    private let captureQueue = DispatchQueue(label: "com.dictai.systemAudio.capture")
    private let processingQueue = DispatchQueue(label: "com.dictai.systemAudio.processing", qos: .userInitiated)
    private var capture: Capture?
    private var interruption: FlutterError?
    // A failed stop is still an owned stream. Keep its retryable operation
    // even after the capture/writer state has been cancelled.
    private var teardowns: [ObjectIdentifier: AudioStreamTeardown] = [:]
    private var processingJobs: [UUID: (BoundedWAV.Cancellation, Reply)] = [:]

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let reply = Reply(result)
        let arguments = call.arguments as? [String: Any]
        switch call.method {
        case "requestPermission":
            captureQueue.asyncAfter(deadline: .now() + 30) { reply.send(false) }
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { _, error in
                self.captureQueue.async { reply.send(error == nil) }
            }
        case "startRecording":
            guard let path = arguments?["path"] as? String, path.hasPrefix("/") else {
                reply.send(Self.error("BAD_ARGS", "An absolute output path is required."))
                return
            }
            captureQueue.async { self.start(output: URL(fileURLWithPath: path), reply: reply) }
        case "stopRecording":
            captureQueue.async { self.stop(reply: reply) }
        case "cancelRecording":
            captureQueue.async {
                if let current = self.capture {
                    if let stream = current.stream { _ = self.teardown(for: stream) }
                    current.cancellation.cancel()
                    self.finish(current, error: Self.error("CANCELLED", "System audio capture was cancelled."),
                                requestStreamStop: false)
                }
                for (cancellation, pending) in self.processingJobs.values {
                    cancellation.cancel()
                    pending.send(Self.error("CANCELLED", "Audio processing was cancelled."))
                }
                self.processingJobs.removeAll()
                self.interruption = nil
                let pending = Array(self.teardowns.values)
                guard !pending.isEmpty else {
                    reply.send(nil)
                    return
                }
                var outstanding = pending.count
                var failure: FlutterError?
                for teardown in pending {
                    teardown.request { error in
                        if let error {
                            failure = Self.stopError(error)
                        }
                        outstanding -= 1
                        if outstanding == 0 { reply.send(failure) }
                    }
                }
            }
        case "mixWavFiles":
            guard let system = arguments?["systemPath"] as? String, system.hasPrefix("/"),
                  let microphone = arguments?["microphonePath"] as? String, microphone.hasPrefix("/"),
                  let output = arguments?["outputPath"] as? String, output.hasPrefix("/") else {
                reply.send(Self.error("BAD_ARGS", "Absolute paths for both inputs and the output are required."))
                return
            }
            captureQueue.async {
                let id = UUID()
                let cancellation = BoundedWAV.Cancellation()
                self.processingJobs[id] = (cancellation, reply)
                self.processingQueue.async {
                    let failure: FlutterError?
                    do {
                        try BoundedWAV.mix(system: URL(fileURLWithPath: system),
                                           microphone: URL(fileURLWithPath: microphone),
                                           output: URL(fileURLWithPath: output),
                                           cancellation: cancellation)
                        failure = nil
                    } catch {
                        failure = Self.error("MIX_FAILED", "The combined WAV could not be created.")
                    }
                    self.captureQueue.async {
                        self.processingJobs.removeValue(forKey: id)
                        reply.send(failure)
                    }
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func error(_ code: String, _ message: String) -> FlutterError {
        FlutterError(code: code, message: message, details: nil)
    }

    private static func stopError(_ error: Error) -> FlutterError {
        if case AudioStreamTeardown.Failure.timeout = error {
            return Self.error("STOP_TIMEOUT", "System audio cancellation was not confirmed.")
        }
        return Self.error("STOP_FAILED", "System audio cancellation could not be confirmed.")
    }

    private func teardown(for stream: SCStream) -> AudioStreamTeardown {
        let id = ObjectIdentifier(stream)
        if let teardown = teardowns[id] { return teardown }
        let teardown = AudioStreamTeardown(queue: captureQueue) { completion in
            stream.stopCapture(completionHandler: completion)
        }
        teardown.onConfirmed = { [weak self, weak teardown] in
            guard let self, let teardown, self.teardowns[id] === teardown else { return }
            self.teardowns.removeValue(forKey: id)
        }
        teardowns[id] = teardown
        return teardown
    }

    private func start(output: URL, reply: Reply) {
        guard capture == nil else {
            reply.send(Self.error("ALREADY_RECORDING", "System audio capture is already active."))
            return
        }
        guard teardowns.isEmpty else {
            reply.send(Self.error("CLEANUP_PENDING", "The previous system audio stream has not confirmed its stop."))
            return
        }
        guard !FileManager.default.fileExists(atPath: output.path) else {
            reply.send(Self.error("OUTPUT_EXISTS", "The output file already exists."))
            return
        }
        let current: Capture
        do {
            current = try Capture(output: output, reply: reply)
        } catch {
            reply.send(Self.error("WRITER_SETUP_FAILED", "The system audio file could not be opened."))
            return
        }
        interruption = nil
        capture = current
        watch(current, phase: .starting, error: Self.error("START_TIMEOUT", "System audio capture did not start."))
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { [weak current] content, error in
            guard let current else { return }
            self.captureQueue.async {
                guard self.capture === current, current.phase == .starting else { return }
                if error != nil {
                    self.finish(current, error: Self.error("PERMISSION_DENIED", "System audio recording permission is unavailable."))
                    return
                }
                guard let display = content?.displays.first else {
                    self.finish(current, error: Self.error("NO_DISPLAY", "No display is available for system audio capture."))
                    return
                }
                self.startStream(current, display: display)
            }
        }
    }

    private func startStream(_ current: Capture, display: SCDisplay) {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48000
        configuration.channelCount = 2
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        do {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: captureQueue)
        } catch {
            finish(current, error: Self.error("STREAM_SETUP_FAILED", "The system audio stream could not be configured."))
            return
        }
        current.stream = stream
        stream.startCapture { [weak current] error in
            self.captureQueue.async {
                guard let current, self.capture === current, current.phase == .starting else {
                    // An interrupted start already installed retained cleanup.
                    // If absent, that stream's stop was already confirmed.
                    if error == nil { self.teardowns[ObjectIdentifier(stream)]?.request { _ in } }
                    return
                }
                if error != nil {
                    self.finish(current, error: Self.error("START_FAILED", "The system audio stream could not start."))
                    return
                }
                current.phase = .recording
                current.reply?.send(nil)
                current.reply = nil
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        // ScreenCaptureKit calls this on captureQueue, set in startStream.
        guard type == .audio, let current = capture, current.stream === stream,
              current.phase == .starting || current.phase == .recording || current.phase == .stopping,
              current.failure == nil, CMSampleBufferDataIsReady(sample),
              CMSampleBufferGetNumSamples(sample) > 0 else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sample)
        guard timestamp.isNumeric else {
            current.failure = Self.error("WRITE_FAILED", "System audio has an invalid timestamp.")
            return
        }
        if current.writer.status == .unknown {
            guard current.writer.startWriting() else {
                current.failure = Self.error("WRITE_FAILED", "System audio writing could not start.")
                return
            }
            current.writer.startSession(atSourceTime: timestamp)
            current.firstTimestamp = timestamp
        }
        if let first = current.firstTimestamp,
           CMTimeSubtract(timestamp, first).seconds >= Double(BoundedWAV.maxDurationSeconds) {
            current.failure = Self.error("TOO_LONG", "System audio exceeds the two hour recording limit.")
            return
        }
        // Refuse incomplete recordings if storage cannot keep up with capture.
        guard current.writer.status == .writing, current.input.isReadyForMoreMediaData,
              current.input.append(sample) else {
            current.failure = Self.error("WRITE_FAILED", "System audio writing was interrupted.")
            return
        }
        current.didWrite = true
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        captureQueue.async {
            if let current = self.capture, current.stream === stream {
                let failure = Self.error("CAPTURE_INTERRUPTED", "System audio capture was interrupted.")
                self.finish(current, error: failure, requestStreamStop: false)
            }
            // ScreenCaptureKit has already stopped this stream. This also
            // resolves retained cleanup after cancellation detached the capture.
            self.teardowns[ObjectIdentifier(stream)]?.confirmStopped()
        }
    }

    private func stop(reply: Reply) {
        guard let current = capture else {
            reply.send(interruption ?? Self.error("NOT_RECORDING", "No system audio recording is active."))
            interruption = nil
            return
        }
        guard current.phase == .recording, let stream = current.stream else {
            reply.send(Self.error("CAPTURE_BUSY", "A system audio capture operation is already pending."))
            return
        }
        current.phase = .stopping
        current.reply = reply
        teardown(for: stream).request { [weak current] error in
            guard let current else { return }
            guard self.capture === current, current.phase == .stopping else { return }
            if let error {
                self.finish(current, error: Self.stopError(error), requestStreamStop: false)
                return
            }
            try? stream.removeStreamOutput(self, type: .audio)
            current.stream = nil
            self.finishWriter(current)
        }
    }

    private func finishWriter(_ current: Capture) {
        if let failure = current.failure {
            finish(current, error: failure)
            return
        }
        guard current.didWrite else {
            finish(current, error: Self.error("NO_AUDIO", "No system audio was captured."))
            return
        }
        guard current.writer.status == .writing else {
            finish(current, error: Self.error("WRITE_FAILED", "System audio writing was interrupted."))
            return
        }
        current.phase = .finishing
        current.input.markAsFinished()
        watch(current, phase: .finishing, error: Self.error("WRITE_TIMEOUT", "System audio writing did not finish."))
        current.writer.finishWriting { [weak current] in
            guard let current else { return }
            self.captureQueue.async {
                guard self.capture === current, current.phase == .finishing else { return }
                guard current.writer.status == .completed else {
                    self.finish(current, error: Self.error("WRITE_FAILED", "System audio writing did not finish."))
                    return
                }
                current.phase = .converting
                self.watch(current, phase: .converting,
                           error: Self.error("CONVERT_TIMEOUT", "System audio conversion did not finish."),
                           seconds: 900)
                self.processingQueue.async {
                    let failure: FlutterError?
                    do {
                        try BoundedWAV.convert(input: current.scratch, output: current.output,
                                               cancellation: current.cancellation)
                        failure = nil
                    } catch {
                        failure = Self.error("CONVERT_FAILED", "System audio could not be converted to WAV.")
                    }
                    self.captureQueue.async { self.finish(current, error: failure) }
                }
            }
        }
    }

    private func watch(_ current: Capture, phase: Phase, error: FlutterError, seconds: Double = 30) {
        captureQueue.asyncAfter(deadline: .now() + seconds) { [weak current] in
            guard let current, self.capture === current, current.phase == phase else { return }
            current.cancellation.cancel()
            self.finish(current, error: error, requestStreamStop: true)
        }
    }

    private func finish(_ current: Capture, error: FlutterError?, requestStreamStop: Bool = true) {
        guard capture === current else { return }
        if let stream = current.stream {
            try? stream.removeStreamOutput(self, type: .audio)
            if requestStreamStop { teardown(for: stream).request { _ in } }
        }
        if current.writer.status == .writing { current.writer.cancelWriting() }
        try? FileManager.default.removeItem(at: current.scratch)
        if let error, current.reply == nil { interruption = error }
        current.reply?.send(error)
        current.reply = nil
        capture = nil
    }
}

/// A retained ScreenCaptureKit stop operation. All state belongs to `queue`.
/// Failures keep the stop closure (and its stream) for retry. Only a confirmed
/// stop releases it; delayed callbacks are scoped to this operation.
final class AudioStreamTeardown {
    enum Failure: Error { case timeout }
    private let queue: DispatchQueue
    private let timeout: Double
    private var stop: ((@escaping (Error?) -> Void) -> Void)?
    private var attempt = 0
    private var active = false
    private var replies: [(Error?) -> Void] = []
    private var deadline: DispatchWorkItem?
    private(set) var isConfirmed = false
    var onConfirmed: (() -> Void)?

    init(queue: DispatchQueue, timeout: Double = 30,
         stop: @escaping (@escaping (Error?) -> Void) -> Void) {
        self.queue = queue
        self.timeout = timeout
        self.stop = stop
    }

    func request(_ reply: @escaping (Error?) -> Void) {
        if isConfirmed { reply(nil); return }
        replies.append(reply)
        if active { return }
        active = true
        attempt += 1
        let id = attempt
        let timer = DispatchWorkItem { [weak self] in
            guard let self, self.active, self.attempt == id else { return }
            self.failed(Failure.timeout)
        }
        deadline = timer
        queue.asyncAfter(deadline: .now() + timeout, execute: timer)
        stop? { error in
            self.queue.async {
                if error == nil {
                    self.confirmStopped()
                } else if self.active, self.attempt == id {
                    self.failed(error!)
                }
            }
        }
    }

    func confirmStopped() {
        guard !isConfirmed else { return }
        isConfirmed = true
        active = false
        deadline?.cancel()
        stop = nil
        onConfirmed?()
        complete(nil)
    }

    private func failed(_ error: Error) {
        active = false
        deadline?.cancel()
        complete(error)
    }

    private func complete(_ error: Error?) {
        let callbacks = replies
        replies.removeAll()
        callbacks.forEach { $0(error) }
    }
}

/// Local-file conversion shared by system finalization and the two-input mix.
/// A persistent converter preserves resampling across fixed-size blocks.
enum BoundedWAV {
    enum Failure: Error { case conversion, empty, limit, outputExists, cancelled }

    final class Cancellation {
        private let lock = NSLock()
        private var cancelled = false

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }

        func check() throws {
            lock.lock()
            let value = cancelled
            lock.unlock()
            if value { throw Failure.cancelled }
        }

        func publish(_ action: () throws -> Void) throws {
            lock.lock()
            defer { lock.unlock() }
            if cancelled { throw Failure.cancelled }
            try action()
        }
    }

    static let blockFrames = 4096
    static let sampleRate = 16000
    static let maxDurationSeconds = 7200
    private static let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: Double(sampleRate), channels: 1,
                                               interleaved: false)!

    private final class Reader {
        private let file: AVAudioFile
        private let converter: AVAudioConverter
        private let input: AVAudioPCMBuffer
        private let output: AVAudioPCMBuffer
        private var offset = 0
        private var finished = false

        init(_ url: URL) throws {
            file = try AVAudioFile(forReading: url)
            let source = file.processingFormat
            guard source.sampleRate >= 8000, source.sampleRate <= 192000,
                  (1...8).contains(source.channelCount),
                  let converter = AVAudioConverter(from: source, to: format),
                  let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(blockFrames)),
                  let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(blockFrames)) else {
                throw Failure.conversion
            }
            converter.downmix = true
            guard file.length > 0 else { throw Failure.empty }
            guard Double(file.length) / source.sampleRate <= Double(maxDurationSeconds) else {
                throw Failure.limit
            }
            self.converter = converter
            self.input = input
            self.output = output
        }

        func readBlock() throws -> [Float] {
            var block: [Float] = []
            block.reserveCapacity(blockFrames)
            var emptyPasses = 0
            while block.count < blockFrames {
                if offset == Int(output.frameLength) {
                    if finished { break }
                    try refill()
                    if output.frameLength == 0 {
                        emptyPasses += 1
                        if emptyPasses >= 8 { throw Failure.conversion }
                        continue
                    }
                }
                guard let samples = output.floatChannelData?[0] else { throw Failure.conversion }
                let count = min(blockFrames - block.count, Int(output.frameLength) - offset)
                block.append(contentsOf: UnsafeBufferPointer(start: samples + offset, count: count))
                offset += count
            }
            return block
        }

        private func refill() throws {
            var readError: Error?
            var convertError: NSError?
            output.frameLength = 0
            offset = 0
            let status = converter.convert(to: output, error: &convertError) { count, state in
                if readError == nil {
                    do {
                        // AVAudioFile can throw at EOF instead of returning an
                        // empty buffer. Signal converter EOF before that read.
                        if self.file.framePosition >= self.file.length {
                            state.pointee = .endOfStream
                            return nil
                        }
                        try self.file.read(into: self.input, frameCount: max(1, min(count, self.input.frameCapacity)))
                        if self.input.frameLength > 0 {
                            state.pointee = .haveData
                            return self.input
                        }
                    } catch {
                        readError = error
                    }
                }
                state.pointee = .endOfStream
                return nil
            }
            if readError != nil || convertError != nil || status == .error { throw Failure.conversion }
            finished = status == .endOfStream
        }
    }

    static func convert(input: URL, output: URL, cancellation: Cancellation = Cancellation()) throws {
        try cancellation.check()
        let reader = try Reader(input)
        try write(output: output, cancellation: cancellation) { try reader.readBlock() }
    }

    static func mix(system: URL, microphone: URL, output: URL,
                    cancellation: Cancellation = Cancellation()) throws {
        try cancellation.check()
        let system = try Reader(system)
        let microphone = try Reader(microphone)
        var first = true
        try write(output: output, cancellation: cancellation) {
            var block = try system.readBlock()
            let mic = try microphone.readBlock()
            if first {
                first = false
                guard !block.isEmpty, !mic.isEmpty else { throw Failure.empty }
            }
            if mic.count > block.count {
                block.append(contentsOf: repeatElement(0, count: mic.count - block.count))
            }
            for index in block.indices {
                block[index] = block[index] * 0.8 + (index < mic.count ? mic[index] * 0.8 : 0)
            }
            return block
        }
    }

    private static func write(output: URL, cancellation: Cancellation,
                              nextBlock: () throws -> [Float]) throws {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: output.path) else { throw Failure.outputExists }
        let partial = output.deletingLastPathComponent().appendingPathComponent(".dictai-wav-\(UUID()).partial")
        guard manager.createFile(atPath: partial.path, contents: nil) else { throw Failure.conversion }
        defer { try? manager.removeItem(at: partial) }
        let handle = try FileHandle(forWritingTo: partial)
        defer { try? handle.close() }
        try handle.write(contentsOf: Data(repeating: 0, count: 44))
        var frames = 0
        while true {
            try cancellation.check()
            let block = try nextBlock()
            if block.isEmpty { break }
            frames += block.count
            guard frames <= sampleRate * maxDurationSeconds else { throw Failure.limit }
            var bytes = Data(capacity: block.count * 2)
            for sample in block {
                guard sample.isFinite else { throw Failure.conversion }
                let clamped = min(1, max(-1, sample))
                let value = clamped == -1 ? Int16.min : Int16((clamped * Float(Int16.max)).rounded())
                append(UInt16(bitPattern: value), to: &bytes)
            }
            try handle.write(contentsOf: bytes)
        }
        guard frames > 0 else { throw Failure.empty }
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: header(dataBytes: UInt32(frames * 2)))
        try handle.close()
        // Atomic publication on the same filesystem, without replacing a file.
        try cancellation.publish { try manager.moveItem(at: partial, to: output) }
    }

    private static func header(dataBytes: UInt32) -> Data {
        var result = Data("RIFF".utf8)
        append(dataBytes + 36, to: &result)
        result.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16), to: &result)
        append(UInt16(1), to: &result)
        append(UInt16(1), to: &result)
        append(UInt32(sampleRate), to: &result)
        append(UInt32(sampleRate * 2), to: &result)
        append(UInt16(2), to: &result)
        append(UInt16(16), to: &result)
        result.append(contentsOf: "data".utf8)
        append(dataBytes, to: &result)
        return result
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var encoded = value.littleEndian
        withUnsafeBytes(of: &encoded) { data.append(contentsOf: $0) }
    }
}
