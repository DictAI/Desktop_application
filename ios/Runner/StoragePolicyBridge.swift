import Flutter
import UIKit

/// Protects only directories owned by DictAI's journal/import/cache adapters.
/// Files picked by the user and copies exported to Files are outside this set.
final class StoragePolicyBridge {
  private let channel: FlutterMethodChannel
  private static let manager = FileManager.default
  private static let protection = FileProtectionType.completeUntilFirstUserAuthentication

  private enum PolicyError: Error { case invalidPath, unsupportedItem, protectionVerification, backupVerification }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.dictai/ios_storage_policy", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "protect" else { result(FlutterMethodNotImplemented); return }
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "invalid_path", message: "Local file protection unavailable.", details: nil))
        return
      }
      do {
        result(try Self.protectOwnedPath(path))
      } catch {
        // Neither native exception text nor the private path crosses the channel.
        result(FlutterError(code: "protection_failed", message: "Local file protection unavailable.", details: nil))
      }
    }
  }

  /// The return value is built only after reading each actual resource/attribute.
  /// Internal visibility permits native XCTest to check the same production path.
  static func protectOwnedPath(_ path: String) throws -> [String: Any] {
    guard path.hasPrefix("/"), !path.contains("\0") else { throw PolicyError.invalidPath }
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let ownedRoot = try permittedRoot(for: url)
    try validate(url, inside: ownedRoot)
    // The shared journal container is prepared before choosing an account.
    // Touch only that directory's metadata: another owner's damaged subtree
    // must not be traversed, modified, or allowed to block the current owner.
    let sharedJournalContainer = ownedRoot.lastPathComponent == "dictai-pending-v1"
      && url.resolvingSymlinksInPath() == ownedRoot
    // Per-owner/staging traversal throws on an unreadable child rather than
    // quietly treating a partially protected tree as success.
    let items: [URL]
    if sharedJournalContainer { items = [url] }
    else { items = try descendants(of: url, inside: ownedRoot) }
    var protectionVerified = true
    #if targetEnvironment(simulator)
    let environment = "simulator"
    #else
    let environment = "device"
    #endif
    for item in items {
      try manager.setAttributes([.protectionKey: protection], ofItemAtPath: item.path)
      var protectedURL = item
      var resources = URLResourceValues()
      resources.isExcludedFromBackup = true
      try protectedURL.setResourceValues(resources)
      let actual = try manager.attributesOfItem(atPath: item.path)
      // Use a fresh URL so a cached pre-write resource value cannot pass/fail
      // verification independently of the actual on-disk backup attribute.
      let resource = try URL(fileURLWithPath: item.path)
        .resourceValues(forKeys: [.isExcludedFromBackupKey])
      let actualProtection = (actual[.protectionKey] as? FileProtectionType)?.rawValue
        ?? (actual[.protectionKey] as? String)
      if actualProtection != protection.rawValue {
        #if targetEnvironment(simulator)
        // Simulator runs on the host filesystem, where NSFileProtection may be
        // absent even after a successful setAttributes. Report that capability
        // explicitly; never report it as verified iPhone data protection.
        guard actualProtection == nil else { throw PolicyError.protectionVerification }
        protectionVerified = false
        #else
        // No runtime argument or Dart flag can bypass device verification.
        throw PolicyError.protectionVerification
        #endif
      }
      guard resource.isExcludedFromBackup == true else { throw PolicyError.backupVerification }
    }
    return ["excludedFromBackup": true,
            "protection": protectionVerified ? "completeUntilFirstUserAuthentication" : "unsupportedInSimulator",
            "protectionVerified": protectionVerified, "environment": environment]
  }

  private static func descendants(of url: URL, inside root: URL) throws -> [URL] {
    try validate(url, inside: root)
    var items = [url]
    if try itemType(url) == .typeDirectory {
      for child in try manager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
        items += try descendants(of: child, inside: root)
      }
    }
    return items
  }

  private static func permittedRoot(for input: URL) throws -> URL {
    let resolved = input.resolvingSymlinksInPath()
    let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    let temporary = [URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)]
      + manager.urls(for: .cachesDirectory, in: .userDomainMask)
    for base in support + temporary {
      let canonical = base.standardizedFileURL.resolvingSymlinksInPath()
      guard resolved.path.hasPrefix(canonical.path + "/") else { continue }
      let remainder = resolved.path.dropFirst(canonical.path.count + 1)
      guard let first = remainder.split(separator: "/").first else { continue }
      let name = String(first)
      let isSupport = support.contains { $0.standardizedFileURL.resolvingSymlinksInPath() == canonical }
      let allowed = isSupport ? name == "dictai-pending-v1"
        : ["dictai-original-", "dictai-wav-import-", "dictai-ios-capture-",
           "dictai-export-", "dictai-download-"].contains {
          name.hasPrefix($0) && name.count > $0.count
        }
      if allowed { return canonical.appendingPathComponent(name, isDirectory: true) }
    }
    throw PolicyError.invalidPath
  }

  private static func validate(_ url: URL, inside root: URL) throws {
    // Resolve system aliases such as /var -> /private/var, then reject any links
    // in our owned subtree. Canonical containment alone would accept a link into
    // another owned directory and change files belonging to a different owner.
    let resolved = url.resolvingSymlinksInPath()
    guard resolved.path == root.path || resolved.path.hasPrefix(root.path + "/") else {
      throw PolicyError.invalidPath
    }
    var cursor = url
    while true {
      if try itemType(cursor) == .typeSymbolicLink { throw PolicyError.unsupportedItem }
      let canonical = cursor.resolvingSymlinksInPath()
      if canonical.path == root.path { break }
      let parent = cursor.deletingLastPathComponent()
      guard parent.path != cursor.path else { throw PolicyError.invalidPath }
      cursor = parent
    }
    let type = try itemType(url)
    guard type == .typeDirectory || type == .typeRegular else { throw PolicyError.unsupportedItem }
    if type == .typeRegular {
      let attributes = try manager.attributesOfItem(atPath: url.path)
      // A hard link can otherwise mutate attributes of a file outside our store.
      guard (attributes[.referenceCount] as? NSNumber)?.intValue == 1 else {
        throw PolicyError.unsupportedItem
      }
    }
  }

  private static func itemType(_ url: URL) throws -> FileAttributeType {
    guard let type = try manager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType else {
      throw PolicyError.unsupportedItem
    }
    return type
  }
}
