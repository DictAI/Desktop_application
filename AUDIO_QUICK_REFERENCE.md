================================================================================
QUICK REFERENCE - AUDIO RECORDING FILES
================================================================================

📁 FILE TREE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

lib/features/record/
├── data/
│   ├── system_audio_service.dart          [Dart ↔ Swift bridge for ScreenCaptureKit]
│   ├── audio_ingest_api.dart              [Backend upload API client]
│   └── anthropic_service.dart             [Claude API integration]
├── presentation/
│   ├── record_notifier.dart               [State management (Riverpod)]
│   ├── record_screen.dart                 [Main UI - Recording controls]
│   ├── upload_modal.dart                  [Upload file dialog]
│   └── chat_panel.dart                    [Claude chat widget]

lib/shared/
└── providers/
    └── providers.dart                     [Riverpod provider setup]

macos/
├── Runner/
│   ├── SystemAudioRecorder.swift          [★ Native ScreenCaptureKit implementation]
│   ├── AppDelegate.swift                  [Method channel setup]
│   ├── MainFlutterWindow.swift            [Window configuration]
│   └── Info.plist                         [App permissions]
└── Flutter/
    └── GeneratedPluginRegistrant.swift    [Auto-generated plugin registry]

Root Files:
├── pubspec.yaml                           [Dependencies (record ^5.1.2)]
└── pubspec.lock                           [Locked versions]


📊 DATA FLOW DIAGRAM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────────────────────────┐
│                       FLUTTER UI LAYER                         │
│ record_screen.dart → record_notifier.dart (StateNotifier)      │
└────────────┬────────────────────────────────────────────────────┘
             │
             ├─ Microphone ────────┐
             │                     │
             └─ System Audio ──────┼──────────────────────────┐
                                   │                          │
             ┌─────────────────────┘                          │
             │                                                │
      ┌──────▼─────────────────────┐              ┌───────────▼────────┐
      │  Flutter Dart Layer        │              │   Backend API      │
      ├────────────────────────────┤              ├────────────────────┤
      │ system_audio_service.dart  │              │ /ingest/audio/     │
      │ (MethodChannel Bridge)     │              │ upload (POST)       │
      └──────────┬──────────────────┘              └────────────────────┘
                 │
                 │ Native Method Channel: "com.dictai/system_audio"
                 │
      ┌──────────▼──────────────────────────────────────────────┐
      │         macOS Native Layer (Swift)                      │
      ├───────────────────────────────────────────────────────┤
      │ SystemAudioRecorder.swift                            │
      │   ├─ ScreenCaptureKit (SCStream)                     │
      │   ├─ AVAudioEngine (Microphone)                      │
      │   └─ Audio Mixing (Accelerate vDSP)                  │
      └───────────────────────────────────────────────────────┘


🎯 KEY METHODS BY FILE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

system_audio_service.dart
  ✓ requestPermission() → Future<bool>
  ✓ startRecording(mode) → Future<String>
  ✓ stopRecording() → Future<void>

audio_ingest_api.dart
  ✓ uploadAudio(workspaceId, audioFile, onProgress) → Future<String>

anthropic_service.dart
  ✓ getApiKey() → Future<String?>
  ✓ saveApiKey(key) → Future<void>
  ✓ send(messages) → Future<String>

record_notifier.dart
  ✓ toggleRecording() → Future<void>
  ✓ togglePause() → Future<void>
  ✓ setAudioSource(source) → void
  ✓ selectDevice(device) → void
  ✓ selectWorkspace(id, name) → void
  ✓ uploadFile(file) → Future<void>
  ✓ _startMicrophone() → Future<void>
  ✓ _startSystemAudio() → Future<void>
  ✓ _stopAndUpload() → Future<void>

SystemAudioRecorder.swift
  ✓ requestPermission(result) → void
  ✓ startRecording(path, mode, result) → void
  ✓ stopRecording(result) → void
  ✓ mixWAV(sysPath, micPath, outputPath, completion) → void
  ✓ setupWriter(path, writerRef, inputRef) → void


📋 ENUM VALUES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RecordStatus:
  • idle
  • recording
  • paused
  • uploading
  • done
  • error

AudioSource:
  • microphone
  • systemAudio
  • systemAndMicrophone


🔌 NATIVE CHANNEL INTERFACE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Channel Name: "com.dictai/system_audio"

Methods:
  1. requestPermission()
     Response: bool (true if granted)

  2. startRecording(args)
     Args: { path: String, mode: String ("system"|"both") }
     Response: null or error

  3. stopRecording()
     Response: null or error

Error Codes (Swift → Dart):
  • PERMISSION_DENIED
  • NO_DISPLAY
  • START_FAILED
  • MIC_FAILED
  • STREAM_SETUP_FAILED
  • NO_AUDIO


🎚️ AUDIO SPECIFICATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Format:          WAV (uncompressed)
Sample Rate:     16000 Hz
Channels:        1 (Mono)
Bit Depth:       16-bit
Encoding:        Linear PCM (little-endian)
File Size/min:   ~1.92 MB
Duration (100MB): ~52 minutes


🔐 PERMISSIONS REQUIRED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Info.plist Keys:
  ✓ NSMicrophoneUsageDescription
    "Microphone access is required to record meetings."

  ✓ NSScreenCaptureUsageDescription
    "Screen capture access is required to record system audio from meetings."

System Settings Path:
  macOS 13+ → Settings → Privacy & Security →
    • Microphone
    • Screen & System Audio Recording


📦 DEPENDENCIES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Direct:
  • record: ^5.1.2                    [Microphone recording]
  • file_picker: ^8.0.3               [File selection]
  • path_provider: ^2.1.4             [Temp directory access]
  • flutter_riverpod: ^2.5.1          [State management]
  • dio: ^5.4.3+1                     [HTTP client]
  • flutter_secure_storage: ^9.0.0    [Secure key storage]

Platform-Specific (Transitive):
  • record_darwin: ^1.2.2             [macOS audio]
  • record_android: ^1.5.1            [Android audio]
  • record_linux: ^1.3.0              [Linux audio]
  • record_windows: ^1.0.7            [Windows audio]
  • record_web: ^1.3.0                [Web audio]
  • record_platform_interface: ^1.5.0 [Interface]


🌐 API ENDPOINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Audio Ingest:
  POST /ingest/audio/upload
  Multipart Form:
    • workspace_id: String (field)
    • audio: File (WAV)
  Response: { "audio_id": "UUID" }
  Errors: 400, 401, 404

Claude API:
  POST https://api.anthropic.com/v1/messages
  Model: claude-sonnet-4-5
  Max Tokens: 1024


🛠️ TROUBLESHOOTING QUICK LOOKUP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Error Message                          → File to Check
─────────────────────────────────────────────────────────────────────────────
"Microphone permission denied"         → SystemAudioRecorder.swift
                                          Info.plist (NSMicrophoneUsageDescription)

"Screen & System Audio Recording"      → SystemAudioRecorder.swift
"permission denied"                    → Info.plist (NSScreenCaptureUsageDescription)

"No audio was captured"                → SystemAudioRecorder.swift
                                          (finalizeWriters method)

"Failed to start system audio capture" → SystemAudioRecorder.swift
                                          (startRecording method)

Upload fails with 400                  → audio_ingest_api.dart
                                          (uploadAudio method)

Upload fails with 401                  → providers.dart (dioProvider)
                                          secure_storage.dart

No device in dropdown                  → record_notifier.dart
                                          (_loadDevices method)


⚙️ CONFIGURATION LOCATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Backend URL:                 providers.dart → dioProvider (http://localhost:8000)
Recording Mode (default):    record_notifier.dart → _startSystemAudio (mode: "system")
Sample Rate:                 record_notifier.dart → RecordConfig (16000)
Max Token (Claude):          anthropic_service.dart → send() (1024)
Method Channel Name:         system_audio_service.dart → _channel ("com.dictai/system_audio")


📝 FILE RELATIONSHIP MATRIX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                        │ Import By         │ Depends On           │ Type
────────────────────────┼───────────────────┼──────────────────────┼──────
record_screen           │ app_router        │ record_notifier      │ UI
record_notifier         │ record_screen     │ system_audio_service │ Logic
                        │                   │ audio_ingest_api     │
system_audio_service    │ record_notifier   │ path_provider        │ Bridge
audio_ingest_api        │ providers         │ dio                  │ API
anthropic_service       │ providers         │ secure_storage       │ API
providers               │ app               │ (all above)          │ Setup
SystemAudioRecorder     │ AppDelegate       │ ScreenCaptureKit     │ Native
AppDelegate             │ main              │ SystemAudioRecorder  │ Setup
Info.plist              │ macOS runner      │ (none)               │ Config

