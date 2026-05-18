import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

    private var systemAudioRecorder: AnyObject?

    override func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 13.0, *) {
            let recorder = SystemAudioRecorder()
            systemAudioRecorder = recorder

            guard let controller = mainFlutterWindow?.contentViewController
                    as? FlutterViewController else { return }

            let channel = FlutterMethodChannel(
                name: SystemAudioRecorder.channelName,
                binaryMessenger: controller.engine.binaryMessenger
            )
            channel.setMethodCallHandler { call, result in
                recorder.handle(call, result: result)
            }
        }
    }

    override func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(
        _ app: NSApplication
    ) -> Bool {
        return true
    }
}
