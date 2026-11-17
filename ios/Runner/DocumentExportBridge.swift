import Flutter
import UIKit

/// Owns one URL-backed activity and completes Dart only after UIKit releases
/// that activity. No public URLs, container exposure or exported copies to delete.
final class DocumentExportBridge: NSObject, UIAdaptivePresentationControllerDelegate {
  private let channel: FlutterMethodChannel
  private var active: Activity?

  private final class Activity {
    let id: String
    let controller: UIActivityViewController
    let result: FlutterResult
    var finishing = false
    var presented = false
    var pendingFinish: (completed: Bool, failed: Bool)?
    var afterDismissals: [() -> Void] = []
    init(id: String, controller: UIActivityViewController, result: @escaping FlutterResult) {
      self.id = id
      self.controller = controller
      self.result = result
    }
  }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.dictai/ios_document_export", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "share": self.share(call.arguments, result: result)
      case "cancel": self.cancel(call.arguments, result: result)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func failure(_ result: FlutterResult, _ code: String) {
    result(FlutterError(code: code, message: "System file export unavailable.", details: nil))
  }

  private func share(_ arguments: Any?, result: @escaping FlutterResult) {
    guard active == nil else { failure(result, "busy"); return }
    guard let args = arguments as? [String: Any],
          let id = args["id"] as? String, !id.isEmpty, id.count <= 120,
          let path = args["path"] as? String,
          let contentType = args["contentType"] as? String else {
      failure(result, "invalid_file"); return
    }
    let url = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
    // path_provider_foundation maps getTemporaryDirectory to Library/Caches on
    // iOS. Accept only our staging layout under either native ephemeral root.
    let roots = ([URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)]
      + FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask))
      .map { $0.standardizedFileURL.resolvingSymlinksInPath() }
    let parent = url.deletingLastPathComponent()
    let exportRoot = parent.deletingLastPathComponent()
    let permitted = ["text/plain": ["transcript.txt", "summary.txt"],
                     "application/pdf": ["transcript.pdf", "summary.pdf"],
                     "audio/wav": ["original.wav"]]
    guard roots.contains(where: { url.path.hasPrefix($0.path + "/") }),
          parent.lastPathComponent.hasPrefix("dictai-download-"),
          exportRoot.lastPathComponent.hasPrefix("dictai-export-"),
          permitted[contentType]?.contains(url.lastPathComponent) == true,
          let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
          values.isRegularFile == true, (values.fileSize ?? 0) > 0 else {
      failure(result, "invalid_file"); return
    }
    guard let scene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive }),
      let rootController = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      failure(result, "no_presenter"); return
    }
    var presenter = rootController
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    guard !presenter.isBeingDismissed, !presenter.isBeingPresented,
          !(presenter is UIAlertController), !(presenter is UIActivityViewController),
          presenter.viewIfLoaded?.window != nil else {
      failure(result, "no_presenter"); return
    }
    let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    // Required even on iPad; use an in-bounds point in the native presenter.
    if let popover = controller.popoverPresentationController {
      popover.sourceView = presenter.view
      let bounds = presenter.view.bounds
      popover.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1)
      popover.permittedArrowDirections = []
    }
    let activity = Activity(id: id, controller: controller, result: result)
    active = activity
    controller.completionWithItemsHandler = { [weak self, weak activity] _, completed, _, error in
      guard let activity = activity else { return }
      self?.finish(activity, completed: completed, failed: error != nil)
    }
    presenter.present(controller, animated: true) { [weak self, weak activity] in
      guard let self = self, let activity = activity,
            self.active === activity else { return }
      activity.presented = true
      controller.presentationController?.delegate = self
      if let pending = activity.pendingFinish {
        self.finish(activity, completed: pending.completed, failed: pending.failed)
      } else {
        self.channel.invokeMethod("presented", arguments: id)
      }
    }
  }

  private func cancel(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any], let id = args["id"] as? String else {
      failure(result, "invalid_request"); return
    }
    guard let activity = active, activity.id == id else { result(nil); return }
    finish(activity, completed: false, failed: false) { result(nil) }
  }

  private func finish(_ activity: Activity, completed: Bool, failed: Bool,
                      afterDismissal: (() -> Void)? = nil) {
    guard active === activity else { afterDismissal?(); return }
    if let callback = afterDismissal { activity.afterDismissals.append(callback) }
    guard !activity.finishing else { return }
    // A cancel can arrive while UIKit is still animating presentation. Finish
    // it from presentation completion, never race dismiss against present.
    guard activity.presented else {
      activity.pendingFinish = (completed, failed)
      return
    }
    activity.finishing = true
    let complete = { [weak self, weak activity] in
      guard let self = self, let activity = activity, self.active === activity else {
        return
      }
      self.active = nil
      activity.controller.completionWithItemsHandler = nil
      if failed { self.failure(activity.result, "provider_failure") }
      else { activity.result(completed ? "completed" : "cancelled") }
      let callbacks = activity.afterDismissals
      activity.afterDismissals.removeAll()
      callbacks.forEach { $0() }
    }
    if activity.controller.presentingViewController != nil {
      activity.controller.dismiss(animated: true, completion: complete)
    } else {
      complete()
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let activity = active, presentationController.presentedViewController === activity.controller else { return }
    finish(activity, completed: false, failed: false)
  }
}
