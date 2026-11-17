import Flutter
import UIKit
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  private let manager = FileManager.default
  private var owned: [URL] = []

  override func tearDownWithError() throws {
    for url in owned.reversed() where manager.fileExists(atPath: url.path) {
      try manager.removeItem(at: url)
    }
    owned.removeAll()
  }

  private func directory(prefix: String = "dictai-original-") throws -> URL {
    let base = try XCTUnwrap(manager.urls(for: .cachesDirectory, in: .userDomainMask).first)
    let url = base.appendingPathComponent(prefix + UUID().uuidString, isDirectory: true)
    try manager.createDirectory(at: url, withIntermediateDirectories: true)
    owned.append(url)
    return url
  }

  private func assertPolicyAttributes(_ url: URL, file: StaticString = #filePath, line: UInt = #line) throws {
    let resource = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
    let attributes = try manager.attributesOfItem(atPath: url.path)
    XCTAssertEqual(resource.isExcludedFromBackup, true, file: file, line: line)
    let protection = (attributes[.protectionKey] as? FileProtectionType)?.rawValue
      ?? (attributes[.protectionKey] as? String)
    #if targetEnvironment(simulator)
    if protection == nil { return } // Explicit unsupported capability, not device evidence.
    #endif
    XCTAssertEqual(protection, FileProtectionType.completeUntilFirstUserAuthentication.rawValue,
      file: file, line: line)
  }

  func testNativeProtectionAttributeCapability() throws {
    let root = try directory()
    let file = root.appendingPathComponent("source.wav")
    try Data([0]).write(to: file)
    for (label, item) in [("directory", root), ("file", file)] {
      try manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: item.path)
      let attributes = try manager.attributesOfItem(atPath: item.path)
      let raw = attributes[.protectionKey]
      let value = (raw as? FileProtectionType)?.rawValue ?? (raw as? String)
      // Diagnostics contain only the synthetic attribute, never private paths.
      let typeName = raw.map { String(describing: type(of: $0)) } ?? "missing"
      print("DICTAI_POLICY_CAPABILITY \(label) type=\(typeName) value=\(value ?? "missing")")
      #if targetEnvironment(simulator)
      if value == nil { continue }
      #endif
      XCTAssertEqual(value, FileProtectionType.completeUntilFirstUserAuthentication.rawValue)
    }
  }

  func testProtectsAndReadsBackDirectoryAndFiles() throws {
    let root = try directory()
    let child = root.appendingPathComponent("dictai-download-test", isDirectory: true)
    try manager.createDirectory(at: child, withIntermediateDirectories: false)
    let wav = child.appendingPathComponent("source.wav")
    let fixture = Data("synthetic-policy-fixture".utf8)
    try fixture.write(to: wav)
    try manager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: wav.path)
    var resources = URLResourceValues()
    resources.isExcludedFromBackup = false
    var unprotected = wav
    try unprotected.setResourceValues(resources)

    let result = try StoragePolicyBridge.protectOwnedPath(root.path)
    XCTAssertEqual(result["excludedFromBackup"] as? Bool, true)
    #if targetEnvironment(simulator)
    XCTAssertEqual(result["environment"] as? String, "simulator")
    let attributes = try manager.attributesOfItem(atPath: root.path)
    let missing = attributes[.protectionKey] == nil
    XCTAssertEqual(result["protectionVerified"] as? Bool, !missing)
    XCTAssertEqual(result["protection"] as? String,
      missing ? "unsupportedInSimulator" : "completeUntilFirstUserAuthentication")
    print("DICTAI_POLICY_SIMULATOR protectionVerified=\(!missing), backupExclusionVerified=true")
    #else
    XCTAssertEqual(result["environment"] as? String, "device")
    XCTAssertEqual(result["protectionVerified"] as? Bool, true)
    XCTAssertEqual(result["protection"] as? String, "completeUntilFirstUserAuthentication")
    #endif
    for item in [root, child, wav] { try assertPolicyAttributes(item) }
    XCTAssertEqual(try Data(contentsOf: wav), fixture)
    // Repeating policy after an atomic rename still checks the actual new file.
    let metadata = child.appendingPathComponent("upload.json")
    try Data("{}".utf8).write(to: metadata, options: .atomic)
    _ = try StoragePolicyBridge.protectOwnedPath(metadata.path)
    try assertPolicyAttributes(metadata)
  }

  func testProtectsOnlySelectedPendingOwner() throws {
    let support = try XCTUnwrap(manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
    let journalRoot = support.appendingPathComponent("dictai-pending-v1", isDirectory: true)
    let owner = journalRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try manager.createDirectory(at: owner, withIntermediateDirectories: true)
    owned.append(owner)
    let stage = owner.appendingPathComponent(".stage-0123456789abcdef0123456789abcdef", isDirectory: true)
    try manager.createDirectory(at: stage, withIntermediateDirectories: false)
    let wav = stage.appendingPathComponent("source.wav")
    try Data([1, 2, 3]).write(to: wav)
    _ = try StoragePolicyBridge.protectOwnedPath(owner.path)
    for item in [owner, stage, wav] { try assertPolicyAttributes(item) }
  }

  func testSharedJournalContainerDoesNotTraverseOtherOwners() throws {
    let support = try XCTUnwrap(manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
    let journalRoot = support.appendingPathComponent("dictai-pending-v1", isDirectory: true)
    let firstOwner = journalRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let secondOwner = journalRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
    for owner in [firstOwner, secondOwner] {
      try manager.createDirectory(at: owner, withIntermediateDirectories: true)
      owned.append(owner)
    }
    let source = firstOwner.appendingPathComponent("source.wav")
    let fixture = Data([12, 13])
    try fixture.write(to: source)
    let broken = secondOwner.appendingPathComponent("unavailable")
    try manager.createSymbolicLink(at: broken,
      withDestinationURL: secondOwner.appendingPathComponent("missing"))
    // A corrupt unrelated owner must not prevent preparing the shared root or
    // protecting a healthy owner. Its subtree remains untouched and rejected
    // when that specific owner is selected instead.
    _ = try StoragePolicyBridge.protectOwnedPath(journalRoot.path)
    try assertPolicyAttributes(journalRoot)
    _ = try StoragePolicyBridge.protectOwnedPath(firstOwner.path)
    try assertPolicyAttributes(source)
    XCTAssertThrowsError(try StoragePolicyBridge.protectOwnedPath(secondOwner.path))
    XCTAssertEqual(try manager.attributesOfItem(atPath: broken.path)[.type] as? FileAttributeType,
      .typeSymbolicLink)
    XCTAssertEqual(try Data(contentsOf: source), fixture)
  }

  func testProtectsExportAndDirectDownloadStaging() throws {
    let export = try directory(prefix: "dictai-export-")
    let download = export.appendingPathComponent("dictai-download-test", isDirectory: true)
    try manager.createDirectory(at: download, withIntermediateDirectories: false)
    let transcript = download.appendingPathComponent("transcript.txt")
    try Data("synthetic transcript".utf8).write(to: transcript)
    _ = try StoragePolicyBridge.protectOwnedPath(export.path)
    for item in [export, download, transcript] { try assertPolicyAttributes(item) }
    let directDownload = try directory(prefix: "dictai-download-")
    _ = try StoragePolicyBridge.protectOwnedPath(directDownload.path)
    try assertPolicyAttributes(directDownload)
  }

  func testRejectsUserFileAndInvalidOwnedPrefix() throws {
    let unrelated = try directory(prefix: "user-files-")
    let source = unrelated.appendingPathComponent("original.wav")
    let fixture = Data([4, 5, 6])
    try fixture.write(to: source)
    XCTAssertThrowsError(try StoragePolicyBridge.protectOwnedPath(source.path))
    XCTAssertEqual(try Data(contentsOf: source), fixture)
    XCTAssertThrowsError(try StoragePolicyBridge.protectOwnedPath("relative/source.wav"))
    XCTAssertThrowsError(try StoragePolicyBridge.protectOwnedPath(unrelated.path + "/missing"))
    let root = try directory()
    XCTAssertThrowsError(try StoragePolicyBridge.protectOwnedPath(root.path + "/missing"))
  }

  func testRejectsSymlinkBeforeChangingAnyFile() throws {
    let unrelated = try directory(prefix: "user-files-")
    let source = unrelated.appendingPathComponent("original.wav")
    let fixture = Data([7, 8, 9])
    try fixture.write(to: source)
    let before = try manager.attributesOfItem(atPath: source.path)[.protectionKey] as? FileProtectionType
    let root = try directory(prefix: "dictai-wav-import-")
    try manager.createSymbolicLink(at: root.appendingPathComponent("source.wav"), withDestinationURL: source)
    XCTAssertThrowsError(try StoragePolicyBridge.protectOwnedPath(root.path))
    XCTAssertEqual(try Data(contentsOf: source), fixture)
    let after = try manager.attributesOfItem(atPath: source.path)[.protectionKey] as? FileProtectionType
    XCTAssertEqual(before, after)
  }

  func testRejectsLinkToAnotherOwnedDirectory() throws {
    let first = try directory()
    let second = try directory()
    let source = second.appendingPathComponent("source.wav")
    try Data([10]).write(to: source)
    let linked = first.appendingPathComponent("linked")
    try manager.createSymbolicLink(at: linked, withDestinationURL: second)
    XCTAssertThrowsError(try StoragePolicyBridge.protectOwnedPath(linked.appendingPathComponent("source.wav").path))
  }

  func testRejectsHardLinkToUserOriginal() throws {
    let unrelated = try directory(prefix: "user-files-")
    let source = unrelated.appendingPathComponent("original.wav")
    try Data([11]).write(to: source)
    let root = try directory()
    try manager.linkItem(at: source, to: root.appendingPathComponent("source.wav"))
    XCTAssertThrowsError(try StoragePolicyBridge.protectOwnedPath(root.path))
    XCTAssertEqual(try Data(contentsOf: source), Data([11]))
  }
}
