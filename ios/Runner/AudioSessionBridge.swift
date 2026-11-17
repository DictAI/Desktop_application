import AVFoundation
import Flutter
import UIKit

/// One microphone recorder and one AVAudioSession owner. All access is on main.
final class AudioSessionBridge: NSObject, FlutterStreamHandler, AVAudioRecorderDelegate {
  private let session = AVAudioSession.sharedInstance()
  private var recorder: AVAudioRecorder?
  private var owner: String?
  private var output: URL?
  private var status = "idle"
  private var revision = 0
  private var generation = 0
  private var interrupted = false
  private var observers: [NSObjectProtocol] = []
  private var sink: FlutterEventSink?
  private var pendingStart: FlutterResult?
  private var channel: FlutterMethodChannel?
  private var events: FlutterEventChannel?
  private var playbackChannel: FlutterMethodChannel?
  private var playbackOwner: String?
  private var playbackInterrupted = false
  private var playbackObservers: [NSObjectProtocol] = []
  private var pendingCapture: String?
  private var pendingCaptureResult: FlutterResult?
  private var pendingCaptureGeneration = 0


  init(messenger: FlutterBinaryMessenger) {
    super.init()
    channel = FlutterMethodChannel(name: "com.dictai/ios_audio", binaryMessenger: messenger)
    events = FlutterEventChannel(name: "com.dictai/ios_audio_events", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      DispatchQueue.main.async {
        self?.handle(call, result: result)
      }
    }
    events?.setStreamHandler(self)
    playbackChannel = FlutterMethodChannel(name: "com.dictai/ios_playback", binaryMessenger: messenger)
    playbackChannel?.setMethodCallHandler { [weak self] call, result in
      DispatchQueue.main.async { self?.handlePlayback(call, result: result) }
    }
    observePlayback()

  }

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    sink = eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func response(_ message: String? = nil) -> [String: Any] {
    var value: [String: Any] = ["id": owner ?? "", "status": status, "revision": revision]
    if let output = output { value["path"] = output.path }
    if let message = message { value["message"] = message }
    return value
  }

  private func publish(_ state: String, _ message: String? = nil) {
    status = state
    revision += 1
    sink?(response(message))
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let id = args["id"] as? String,
          !id.isEmpty else {
      result(FlutterError(code: "invalid_arguments", message: "Missing recorder identity", details: nil))
      return
    }
    if call.method == "start" {
      start(id: id, result: result)
      return
    }
    if call.method == "dispose" && pendingCapture == id {
      cancelPendingCapture("cancelled", "Recording cancelled")
      result(nil)
      return
    }
    // Late cleanup for a previous Dart recorder cannot stop a newer recording.
    if call.method == "dispose" && owner != id {
      result(nil)
      return
    }
    guard owner == id else {
      result(FlutterError(code: "unavailable", message: "Recorder is unavailable", details: nil))
      return
    }
    switch call.method {
    case "pause":
      if status == "recording" {
        recorder?.pause()
        publish("paused")
      }
      result(response())
    case "resume":
      guard !interrupted else {
        result(FlutterError(code: "interrupted", message: "Audio session is interrupted", details: nil))
        return
      }
      guard status == "paused", let recorder = recorder else {
        result(response())
        return
      }
      do {
        try session.setActive(true)
        guard recorder.record() else { throw BridgeError.recording }
        publish("recording")
        result(response())
      } catch {
        fail("Не удалось продолжить запись. Доступный WAV сохранён.")
        result(FlutterError(code: "recording_failed", message: "Could not resume microphone", details: nil))
      }
    case "finish":
      guard status == "recording" || status == "paused" else {
        result(FlutterError(code: "unavailable", message: "No active recording", details: nil))
        return
      }
      recorder?.delegate = nil
      recorder?.stop()
      recorder = nil
      do {
        try deactivate()
        publish("finished")
        result(response())
      } catch {
        publish("failed", "Запись завершена, но аудиосессию не удалось освободить.")
        result(FlutterError(code: "session_cleanup", message: "Could not release audio session", details: nil))
      }
    case "dispose":
      generation += 1
      let pending = pendingStart
      pendingStart = nil
      pending?(FlutterError(code: "cancelled", message: "Recording cancelled", details: nil))
      recorder?.delegate = nil
      recorder?.stop()
      recorder = nil
      do {
        try deactivate()
        owner = nil
        output = nil
        status = "idle"
        result(nil)
      } catch {
        publish("failed", "Не удалось освободить аудиосессию.")
        result(FlutterError(code: "session_cleanup", message: "Could not release audio session", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private enum BridgeError: Error { case recording }

  private func start(id: String, result: @escaping FlutterResult) {
    if owner == id && (status == "recording" || status == "paused") {
      result(response())
      return
    }
    guard owner == nil, pendingCapture == nil else {
      result(FlutterError(code: "busy", message: "Audio session already reserved", details: nil))
      return
    }
    guard let playback = playbackOwner else {
      beginCapture(id: id, result: result)
      return
    }
    // Reserve before crossing into Dart. A second Play/Start cannot acquire the
    // session until every already-started plugin command has actually settled.
    pendingCapture = id
    pendingCaptureResult = result
    pendingCaptureGeneration += 1
    let operation = pendingCaptureGeneration
    playbackChannel?.invokeMethod("stopForCapture", arguments: ["id": playback]) { [weak self] reply in
      DispatchQueue.main.async {
        guard let self = self, self.pendingCapture == id,
              self.pendingCaptureGeneration == operation else { return }
        if reply is FlutterError || self.playbackOwner != nil {
          self.cancelPendingCapture("playback_cleanup", "Could not stop playback")
          return
        }
        let completion = self.pendingCaptureResult
        self.pendingCapture = nil
        self.pendingCaptureResult = nil
        if let completion = completion { self.beginCapture(id: id, result: completion) }
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      guard let self = self, self.pendingCapture == id,
            self.pendingCaptureGeneration == operation else { return }
      // Playback ownership survives a missing ACK until its real release.
      self.cancelPendingCapture("playback_timeout", "Playback did not stop in time")
    }
  }

  private func cancelPendingCapture(_ code: String, _ message: String) {
    pendingCaptureGeneration += 1
    let completion = pendingCaptureResult
    pendingCapture = nil
    pendingCaptureResult = nil
    completion?(FlutterError(code: code, message: message, details: nil))
  }

  private func handlePlayback(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let id = args["id"] as? String, !id.isEmpty else {
      result(FlutterError(code: "invalid_arguments", message: "Missing playback identity", details: nil))
      return
    }
    switch call.method {
    case "acquire":
      guard owner == nil, pendingCapture == nil, !playbackInterrupted,
            UIApplication.shared.applicationState == .active,
            playbackOwner == nil || playbackOwner == id else {
        result(FlutterError(code: "busy", message: "Audio session is unavailable", details: nil))
        return
      }
      do {
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        playbackOwner = id
        result(nil)
      } catch {
        result(FlutterError(code: "playback_failed", message: "Could not acquire audio session", details: nil))
      }
    case "release":
      guard playbackOwner == id else { result(nil); return }
      do {
        if owner == nil { try session.setActive(false, options: .notifyOthersOnDeactivation) }
        playbackOwner = nil
        result(nil)
      } catch {
        result(FlutterError(code: "playback_cleanup", message: "Could not release playback", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func stopPlaybackForSystem() {
    guard let playback = playbackOwner else { return }
    playbackChannel?.invokeMethod("stopForSystem", arguments: ["id": playback])
  }

  private func observePlayback() {
    let center = NotificationCenter.default
    playbackObservers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
      object: session, queue: .main) { [weak self] notification in
        guard let self = self, let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        self.playbackInterrupted = type == .began
        if type == .began { self.stopPlaybackForSystem() }
      })
    playbackObservers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
      object: session, queue: .main) { [weak self] notification in
        guard let self = self, let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        if reason == .oldDeviceUnavailable || reason == .newDeviceAvailable ||
            reason == .routeConfigurationChange || reason == .noSuitableRouteForCategory {
          self.stopPlaybackForSystem()
        }
      })
    playbackObservers.append(center.addObserver(forName: UIApplication.willResignActiveNotification,
      object: nil, queue: .main) { [weak self] _ in self?.stopPlaybackForSystem() })
  }

  deinit {
    playbackObservers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  private func beginCapture(id: String, result: @escaping FlutterResult) {
    if owner == id && (status == "recording" || status == "paused") {
      result(response())
      return
    }
    guard owner == nil else {
      result(FlutterError(code: "busy", message: "A recorder already owns the microphone", details: nil))
      return
    }
    owner = id
    output = nil
    status = "starting"
    revision = 0
    generation += 1
    let operation = generation
    pendingStart = result
    session.requestRecordPermission { [weak self] allowed in
      DispatchQueue.main.async {
        guard let self = self, self.generation == operation, self.owner == id,
              let completion = self.pendingStart else { return }
        self.pendingStart = nil
        guard allowed else {
          self.owner = nil
          self.status = "idle"
          completion(FlutterError(code: "permission_denied", message: "Microphone permission denied", details: nil))
          return
        }
        var stage = "category"
        do {
          // Input-only behavior; do not mix or record other applications' audio.
          try self.session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
          stage = "sample_rate"
          try self.session.setPreferredSampleRate(16000)
          stage = "activate"
          try self.session.setActive(true)
          stage = "directory"
          let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("dictai-ios-capture-\(UUID().uuidString)", isDirectory: true)
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
          var resource = URLResourceValues()
          resource.isExcludedFromBackup = true
          var protectedDirectory = directory
          try protectedDirectory.setResourceValues(resource)
          let url = directory.appendingPathComponent("microphone.wav")
          self.output = url
          stage = "recorder"
          let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
          ]
          let recorder = try AVAudioRecorder(url: url, settings: settings)
          recorder.delegate = self
          self.recorder = recorder
          stage = "prepare"
          guard recorder.prepareToRecord() else { throw BridgeError.recording }
          stage = "protection"
          try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
          self.observeSession()
          stage = "record"
          guard recorder.record() else { throw BridgeError.recording }
          self.publish("recording")
          completion(self.response())
        } catch {
          self.fail("Не удалось начать запись. Проверьте микрофон и свободное место.")
          completion(FlutterError(code: "recording_failed", message: "Could not start microphone", details: stage))
        }
      }
    }
  }

  private func observeSession() {
    removeObservers()
    let center = NotificationCenter.default
    let operation = generation
    observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
      object: session, queue: .main) { [weak self] notification in
        guard let self = self, self.generation == operation, let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
          self.interrupted = true
          if self.status == "recording" {
            self.recorder?.pause()
            self.publish("paused", "Запись приостановлена системой. После прерывания нажмите «Продолжить».")
          }
        } else {
          self.interrupted = false
          if self.status == "paused" {
            self.publish("paused", "Прерывание завершено. Нажмите «Продолжить», чтобы записывать дальше.")
          }
        }
      })
    observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
      object: session, queue: .main) { [weak self] notification in
        guard let self = self, self.generation == operation, self.status == "recording",
              let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        if reason == .oldDeviceUnavailable || reason == .newDeviceAvailable ||
            reason == .routeConfigurationChange || reason == .noSuitableRouteForCategory {
          self.recorder?.pause()
          self.publish("paused", "Аудиоустройство изменилось. Проверьте микрофон и нажмите «Продолжить».")
        }
      })
    observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereLostNotification,
      object: session, queue: .main) { [weak self] _ in
        guard let self = self, self.generation == operation else { return }
        self.fail("Аудиосервис недоступен. Доступный WAV сохранён; начните новую запись.")
      })
    observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
      object: session, queue: .main) { [weak self] _ in
        guard let self = self, self.generation == operation else { return }
        self.fail("Аудиосервис перезапущен. Доступный WAV сохранён; начните новую запись.")
      })
  }

  private func removeObservers() {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    observers.removeAll()
    interrupted = false
  }

  private func deactivate() throws {
    removeObservers()
    try session.setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func fail(_ message: String) {
    guard owner != nil else { return }
    recorder?.delegate = nil
    recorder?.stop()
    recorder = nil
    try? deactivate()
    publish("failed", message)
  }

  func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    guard recorder === self.recorder else { return }
    fail("Запись остановлена устройством. Доступный WAV сохранён; начните новую запись.")
  }

  func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    guard recorder === self.recorder else { return }
    fail("Ошибка записи WAV. Доступный исходник сохранён; начните новую запись.")
  }
}
