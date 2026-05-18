# COMPREHENSIVE AUDIO RECORDING & SCREEN CAPTURE FILES AUDIT
# Project: Dict AI (Flutter Meeting Recording & Transcription App)
# Date: May 7, 2026

================================================================================
OVERVIEW
================================================================================

This Flutter desktop application implements multi-platform audio recording with:
1. Microphone recording (via record package)
2. System audio capture (via ScreenCaptureKit on macOS 13+)
3. Mixed audio recording (system audio + microphone simultaneously)
4. File upload to backend API

================================================================================
CORE AUDIO/RECORDING FILES
================================================================================

1. FLUTTER DART FILES - Data Layer
─────────────────────────────────────────────────────────────────────────────

File: lib/features/record/data/system_audio_service.dart
Path: ./lib/features/record/data/system_audio_service.dart
Size: ~1.2 KB
Purpose: Dart wrapper for native ScreenCaptureKit system audio recording
Key Functions:
  - requestPermission() - Requests "Screen & System Audio Recording" permission
  - startRecording(mode) - Starts audio capture via method channel
    * Modes: "system" (system audio only) or "both" (system + mic mixed)
    * Returns temp .m4a file path
  - stopRecording() - Stops capture and finalizes file
Method Channel: "com.dictai/system_audio"
Platform Support: macOS only (checks Platform.isMacOS)
Runtime Requirements: macOS 13+ (version check done natively)
Notes:
  - Delegates all native implementation to SystemAudioRecorder.swift
  - Uses getTemporaryDirectory() for output files
  - Throws PlatformException on failure


File: lib/features/record/data/audio_ingest_api.dart
Path: ./lib/features/record/data/audio_ingest_api.dart
Size: ~1.4 KB
Purpose: Backend API client for audio file upload
Key Functions:
  - uploadAudio(workspaceId, audioFile, onProgress) - Uploads WAV to backend
    * Multipart form data: workspace_id + audio file
    * Returns audio_id from server
    * Progress callback support
API Endpoint: POST /ingest/audio/upload
Response Format: { "audio_id": "..." }
Error Handling:
  - 400: ValidationException (invalid audio/workspace)
  - 401: UnauthorizedException
  - 404: NotFoundException (workspace not found)
  - Other: ServerException
Notes:
  - Uses Dio HTTP client
  - Extracts filename from file path
  - Tracks upload progress via callback


File: lib/features/record/data/anthropic_service.dart
Path: ./lib/features/record/data/anthropic_service.dart
Size: ~1.8 KB
Purpose: Integration with Claude API for transcription/analysis
Key Functions:
  - getApiKey() - Retrieves Anthropic API key from secure storage
  - saveApiKey(key) - Stores API key securely
  - deleteApiKey() - Removes API key
  - send(messages) - Sends messages to Claude Sonnet 4.5
Model: claude-sonnet-4-5
API Endpoint: https://api.anthropic.com/v1/messages
Timeouts:
  - Connect: 15 seconds
  - Receive: 60 seconds
Max Tokens: 1024
System Prompt: "AI assistant built into meeting recording and transcription app"
Error Handling:
  - 401: Returns '__INVALID_KEY__'
  - No API key: Returns '__NO_KEY__'
  - Other errors: Returns error message string


2. FLUTTER DART FILES - Presentation/State Management
─────────────────────────────────────────────────────────────────────────────

File: lib/features/record/presentation/record_notifier.dart
Path: ./lib/features/record/presentation/record_notifier.dart
Size: ~9 KB
Purpose: State management for recording, audio source selection, and upload
Architecture: StateNotifier + Riverpod (state management)
Key State:
  - RecordStatus: idle, recording, paused, uploading, done, error
  - AudioSource: microphone, systemAudio, systemAndMicrophone
  - RecordState fields:
    * status, audioSource, selectedWorkspaceId, selectedWorkspaceName
    * uploadedAudioId, errorMessage, uploadProgress (0-1)
    * inputDevices (list), selectedDevice

Key Functions:
  - _startRecording() - Routes to microphone or system audio recording
  - _startMicrophone() - Configures and starts record package recording
    * Audio format: WAV, 16kHz mono
    * Permission check + device selection
  - _startSystemAudio() - Initiates ScreenCaptureKit capture via method channel
    * Requests "Screen & System Audio Recording" permission
    * Supports "system" or "both" (mixed) modes
  - _stopAndUpload() - Stops recording and uploads file
  - uploadFile(File) - Manual file upload
  - _loadDevices() - Queries available input devices via record package
  - toggleRecording() - Start/stop recording
  - togglePause() - Pause/resume (microphone only)
  - selectDevice(device) - Choose input device for microphone
  - setAudioSource(source) - Switch between microphone/system/both
  - selectWorkspace(id, name) - Set target workspace
  - reset() - Clear recording state

Internal State:
  - _recorder = AudioRecorder() - From record package
  - _sysAudio = SystemAudioService() - Custom wrapper
  - _sysAudioPath = temp file path during system audio recording

Recording Configuration (Microphone):
  - RecordConfig:
    * encoder: AudioEncoder.wav
    * sampleRate: 16000 Hz
    * numChannels: 1 (mono)
    * device: selected input device

File Paths:
  - Microphone: recording_${timestamp}.wav
  - System audio: sysaudio_${timestamp}.wav

Permissions:
  - Microphone: Checked via _recorder.hasPermission()
  - System audio: Checked via _sysAudio.requestPermission()

Error Messages:
  - "Please select a workspace before recording"
  - "Microphone permission denied"
  - "Screen & System Audio Recording permission denied"
  - "Failed to start/stop system audio capture"
  - "No audio was captured"


File: lib/features/record/presentation/record_screen.dart
Path: ./lib/features/record/presentation/record_screen.dart
Size: ~22 KB
Purpose: UI for recording control, audio source selection, device choice
Key UI Components:
  - _RecordButton - Main circular record/stop button with pulse animation
  - _RecordStatusWidget - Status display (Recording..., Paused, Uploading, etc)
  - _AudioSourceToggle - Switch between Microphone/System/Both
  - _DeviceSelector - Dropdown for input device selection
  - _WorkspaceSelector - Workspace selection with create option
  - _UploadAudioButton - Manual file upload button
  - _UploadProgressBar - Upload progress bar (0-100%)
  - _UploadSuccess - Success banner with audio_id
  - _ErrorBanner - Error message display
  - _CreateWorkspaceDialog - Create new workspace dialog

Logic:
  - Validates workspace has participants with voice profiles before recording
  - Disables recording if validation fails
  - Shows context-appropriate help text for each audio source
  - Supports audio source tooltips and info messages


File: lib/features/record/presentation/upload_modal.dart
Path: ./lib/features/record/presentation/upload_modal.dart
Size: ~4 KB (estimated from code usage)
Purpose: Modal dialog for uploading audio files or selecting files


File: lib/features/record/presentation/chat_panel.dart
Path: ./lib/features/record/presentation/chat_panel.dart
Size: ~4 KB (estimated from code usage)
Purpose: Right-side panel for chat with Claude about recordings


3. NATIVE SWIFT IMPLEMENTATION - macOS System Audio Capture
─────────────────────────────────────────────────────────────────────────────

File: macos/Runner/SystemAudioRecorder.swift
Path: ./macos/Runner/SystemAudioRecorder.swift
Size: ~15 KB
Purpose: Native implementation of system audio recording via ScreenCaptureKit
Availability: @available(macOS 13.0, *)
Method Channel: "com.dictai/system_audio"

Core Classes/Frameworks Used:
  - ScreenCaptureKit (SCStream, SCStreamDelegate, SCStreamOutput)
  - AVFoundation (AVAssetWriter, AVAudioEngine)
  - Accelerate (vDSP for audio mixing)

Key Components:

a) System Audio Recording (ScreenCaptureKit)
   ─────────────────────────────────────────
   Properties:
   - stream: SCStream - ScreenCaptureKit stream
   - sysWriter: AVAssetWriter - Writes system audio to file
   - sysAudioInput: AVAssetWriterInput - Audio input for writer
   - sysOutputPath: String - Path to system audio WAV file
   - sysWriting: Bool - Track write status
   - sysWritingCompleted: Bool - Track completion

   Process:
   1. SCShareableContent.getExcludingDesktopWindows() - Request permission
   2. Create SCContentFilter (capture display, exclude app audio)
   3. Create SCStreamConfiguration:
      - capturesAudio = true
      - excludesCurrentProcessAudio = true
      - width/height = 2x2 (minimal video capture, audio-only)
      - minimumFrameInterval = 1 fps
   4. Create SCStream with filter + config
   5. Add SCStreamOutput with .audio type
   6. stream.startCapture()
   7. SCStreamOutput.stream(didOutputSampleBuffer:) receives audio samples
   8. Append to AVAssetWriterInput
   9. stream.stopCapture() finalizes file

   Audio Format (System):
   - Linear PCM (kAudioFormatLinearPCM)
   - Sample Rate: 16000 Hz
   - Channels: 1 (mono)
   - Bit Depth: 16-bit
   - Endianness: Little-endian
   - Interleaving: Interleaved

b) Microphone Recording (AVAudioEngine)
   ──────────────────────────────────────
   Properties:
   - audioEngine: AVAudioEngine - Audio processing engine
   - micWriter: AVAssetWriter - Writes microphone to file
   - micAudioInput: AVAssetWriterInput - Audio input for writer
   - micOutputPath: String - Path to microphone WAV file
   - micWriting: Bool - Track write status
   - micWritingCompleted: Bool - Track completion

   Process:
   1. Create AVAudioEngine instance
   2. Get inputNode from engine
   3. Get audio format from inputNode.outputFormat(forBus: 0)
   4. Install tap on input node: installTap(onBus:bufferSize:format:block:)
      - Buffer size: 4096 samples
   5. In tap block: convert AVAudioPCMBuffer to CMSampleBuffer
   6. Append to AVAssetWriterInput
   7. engine.start()
   8. engine.stop() and removeTap() when done

   Audio Format (Microphone):
   - Same as system audio (16 kHz, mono, 16-bit PCM)

c) File Mixing (for "both" mode)
   ──────────────────────────────
   Function: mixWAV(sysPath, micPath, outputPath, completion)
   
   Process:
   1. Read both WAV files with AVAudioFile
   2. Load both files into AVAudioPCMBuffer
   3. Use Accelerate framework vDSP_vadd() to mix:
      - Add system audio samples to output buffer
      - Add microphone samples to output buffer
      - Result: mixed mono audio
   4. Write mixed buffer to output WAV file
   5. Delete temporary files

   Audio Mixing Algorithm:
   ```
   For each channel:
     vDSP_vadd(outData[ch], 1, sysData[ch], 1, outData[ch], 1, frameCount)
     vDSP_vadd(outData[ch], 1, micData[ch], 1, outData[ch], 1, frameCount)
   ```
   (Accelerate vector addition)

Methods:

requestPermission() → Bool
  - Calls SCShareableContent.getExcludingDesktopWindows()
  - Returns true if permission granted, false otherwise
  - Side effect: macOS displays permission dialog

startRecording(path, mode, result)
  - mode: "system" or "both"
  - If "both": creates temp paths for both streams, starts mixing after
  - If "system": writes directly to final path
  - Async completion callback with error or nil

stopRecording(result)
  - Stops AVAudioEngine (removes input tap)
  - Stops SCStream (stream.stopCapture())
  - Finalizes all AVAssetWriter instances
  - Coordinates async finalization with DispatchGroup
  - For "both" mode: calls mixWAV() to combine audio
  - Calls result callback when complete

setupWriter(path, writerRef, inputRef)
  - Creates AVAssetWriter for given file path
  - Configures audio format (16 kHz, mono, 16-bit PCM)
  - Adds AVAssetWriterInput to writer
  - Sets expectsMediaDataInRealTime = true

Error Handling:
  - PERMISSION_DENIED - User denied permission
  - NO_DISPLAY - No display found
  - START_FAILED - Stream capture failed
  - MIC_FAILED - Microphone setup failed
  - STREAM_SETUP_FAILED - SCStream setup failed
  - NO_AUDIO - No audio captured (file doesn't exist)

Delegate Methods:
  - stream(_:didOutputSampleBuffer:of:) - SCStreamOutput callback
  - stream(_:didStopWithError:) - SCStreamDelegate callback

AVAudioPCMBuffer Extension:
  - toSampleBuffer(time:) → CMSampleBuffer?
  - Converts AVAudioPCMBuffer to CMSampleBuffer
  - Required for compatibility between AVAudioEngine and AVAssetWriter
  - Creates CMAudioFormatDescription and CMSampleBuffer
  - Sets timing information (presentation time, duration)

File Output Format: WAV (uncompressed PCM)
Sample Output Paths:
  - System only: /tmp/sysaudio_1720000000000.wav
  - System temp: /tmp/sys_1720000000000.wav
  - Microphone temp: /tmp/mic_1720000000000.wav
  - Final mixed: /tmp/sysaudio_1720000000000.wav


4. NATIVE SWIFT - Flutter Integration
─────────────────────────────────────────────────────────────────────────────

File: macos/Runner/AppDelegate.swift
Path: ./macos/Runner/AppDelegate.swift
Size: ~1 KB
Purpose: Sets up Flutter method channel for audio recording

Key Code:
  - Creates SystemAudioRecorder instance
  - Sets up FlutterMethodChannel with name "com.dictai/system_audio"
  - Routes method calls from Dart to SystemAudioRecorder.handle()
  - Only available on macOS 13.0+

Methods:
  - applicationDidFinishLaunching() - Initializes method channel
  - applicationShouldTerminateAfterLastWindowClosed() - Returns true
  - applicationSupportsSecureRestorableState() - Returns true


File: macos/Runner/MainFlutterWindow.swift
Path: ./macos/Runner/MainFlutterWindow.swift
Size: ~1 KB
Purpose: Configures main application window
Notes: Window size setup, minimum size constraints (1100x680)


5. PLATFORM CONFIGURATION
─────────────────────────────────────────────────────────────────────────────

File: macos/Runner/Info.plist
Path: ./macos/Runner/Info.plist
Size: ~1 KB
Purpose: macOS app configuration and permissions

Key Permissions:
  <key>NSMicrophoneUsageDescription</key>
  <string>Microphone access is required to record meetings.</string>

  <key>NSScreenCaptureUsageDescription</key>
  <string>Screen capture access is required to record system audio from meetings.</string>

Notes:
  - These appear in System Settings → Privacy & Security
  - Both required for "both" mode audio recording
  - Screen capture permission gate-keeps ScreenCaptureKit access


================================================================================
DEPENDENCIES & PACKAGES
================================================================================

File: pubspec.yaml
Path: ./pubspec.yaml

Direct Dependencies (Audio/Recording Related):
  - record: ^5.1.2
    * Cross-platform audio recording (microphone)
    * Provides: AudioRecorder, AudioEncoder, InputDevice
    * Platforms: Android, iOS, macOS, Linux, Windows, Web

  - file_picker: ^8.0.3
    * File selection for manual upload
    * Desktop support

  - path_provider: ^2.1.4
    * Access to temporary directories
    * Used for: getTemporaryDirectory()

Platform-Specific Transitive Dependencies (from pubspec.lock):
  - record_darwin: ^1.2.2
    * macOS implementation of record package
    * Native audio recording via AVAudioEngine

  - record_android: ^1.5.1
    * Android implementation (if app extended to Android)

  - record_linux: ^1.3.0
    * Linux implementation (overridden in dependency_overrides)

  - record_web: ^1.3.0
    * Web implementation

  - record_windows: ^1.0.7
    * Windows implementation

  - record_platform_interface: ^1.5.0
    * Interface definitions for platform implementations


================================================================================
FEATURE STRUCTURE
================================================================================

Directory: lib/features/record/
├── data/
│   ├── system_audio_service.dart (Dart ↔ Native bridge)
│   ├── audio_ingest_api.dart (Backend upload API)
│   └── anthropic_service.dart (Claude API integration)
├── presentation/
│   ├── record_notifier.dart (State management - RecordNotifier)
│   ├── record_screen.dart (Main UI - RecordScreen)
│   ├── upload_modal.dart (Upload dialog)
│   └── chat_panel.dart (Chat with Claude)
└── [models/ - if any]

Related Providers:
File: lib/shared/providers/providers.dart
Exposed Providers:
  - secureStorageProvider
  - audioIngestApiProvider
  - anthropicServiceProvider


================================================================================
PERMISSION FLOW
================================================================================

Microphone (via record package):
  1. Flutter: await _recorder.hasPermission() check
  2. Native: RequestUserPermission() for microphone access
  3. macOS: System prompt from Info.plist NSMicrophoneUsageDescription
  4. User: Grant in System Settings → Privacy & Security → Microphone

System Audio (via ScreenCaptureKit):
  1. Flutter: await _sysAudio.requestPermission()
  2. Native: SCShareableContent.getExcludingDesktopWindows()
  3. macOS: System prompt from Info.plist NSScreenCaptureUsageDescription
  4. User: Grant in System Settings → Privacy & Security → Screen & System Audio Recording

ScreenCaptureKit Requirements:
  - macOS 13.0+ (Sonoma or later)
  - System Settings → Privacy & Security → Screen & System Audio Recording
  - App must be in Applications folder (not running from /tmp)


================================================================================
AUDIO PROCESSING PIPELINE
================================================================================

1. MICROPHONE RECORDING PIPELINE
   ─────────────────────────────
   User Action: Select Microphone source → Click Record
        ↓
   Dart: RecordNotifier._startMicrophone()
        ↓
   Dart: _recorder.start(RecordConfig, path)
        ↓
   record_darwin (native): AVAudioEngine setup
        ↓
   Microphone Hardware → Audio Samples (16 kHz, mono, 16-bit)
        ↓
   AVAudioEngine Input Node Tap
        ↓
   Write to WAV file
        ↓
   User Action: Click Stop
        ↓
   Dart: RecordNotifier.toggleRecording()
        ↓
   Dart: _recorder.stop() → returns file path
        ↓
   Dart: RecordNotifier.uploadFile(File)
        ↓
   HTTP POST to /ingest/audio/upload

2. SYSTEM AUDIO RECORDING PIPELINE
   ─────────────────────────────────
   User Action: Select System Audio → Click Record
        ↓
   Dart: RecordNotifier._startSystemAudio()
        ↓
   Dart: _sysAudio.requestPermission() [may show dialog]
        ↓
   Native Swift: SystemAudioRecorder.startRecording(mode: "system")
        ↓
   ScreenCaptureKit SCStream Setup
        ↓
   System Audio Hardware → Audio Samples (16 kHz, mono, 16-bit)
        ↓
   SCStreamOutput callback receives CMSampleBuffer
        ↓
   Write to WAV file via AVAssetWriter
        ↓
   User Action: Click Stop
        ↓
   Dart: RecordNotifier.toggleRecording()
        ↓
   Native Swift: SystemAudioRecorder.stopRecording()
        ↓
   AVAssetWriter finishes file
        ↓
   Dart: RecordNotifier.uploadFile(File)
        ↓
   HTTP POST to /ingest/audio/upload

3. MIXED AUDIO RECORDING PIPELINE (System + Microphone)
   ─────────────────────────────────────────────────────
   User Action: Select "Both" → Click Record
        ↓
   Dart: RecordNotifier._startSystemAudio(mode: "both")
        ↓
   Native Swift: SystemAudioRecorder.startRecording(mode: "both")
        ↓
   Parallel Capture:
   ┌─────────────────────────┐     ┌──────────────────────┐
   │ ScreenCaptureKit        │     │ AVAudioEngine        │
   │ - System Audio Hardware │     │ - Microphone         │
   │ - Write to sys_*.wav    │     │ - Write to mic_*.wav │
   └─────────────────────────┘     └──────────────────────┘
        ↓                                 ↓
   User Action: Click Stop
        ↓
   Native Swift: finalizeWriters()
        ↓
   Both files finalized
        ↓
   Native Swift: mixWAV(sysPath, micPath, outputPath)
        ↓
   Load both files into PCM buffers
        ↓
   Use Accelerate vDSP_vadd() to mix samples
        ↓
   Write to final WAV file
        ↓
   Delete temporary files
        ↓
   Dart: RecordNotifier.uploadFile(File)
        ↓
   HTTP POST to /ingest/audio/upload


================================================================================
FILE PATHS & STORAGE
================================================================================

Temporary File Locations:
  - getTemporaryDirectory() returns platform-specific temp dir
  - macOS: /var/folders/[hash]/T/
  - Files prefixed with timestamp for uniqueness

Naming Convention:
  - Microphone: recording_{millisecondsSinceEpoch}.wav
  - System Audio: sysaudio_{millisecondsSinceEpoch}.wav
  - Temp files (mixed mode): sys_{timestamp}.wav, mic_{timestamp}.wav
  - Example: recording_1720000000000.wav

File Format:
  - Container: WAV (uncompressed)
  - Codec: Linear PCM
  - Sample Rate: 16000 Hz
  - Channels: 1 (mono)
  - Bit Depth: 16-bit
  - File Size Estimate: ~1.92 MB per minute (uncompressed)


================================================================================
BACKEND INTEGRATION
================================================================================

File Upload API:
  Endpoint: POST /ingest/audio/upload
  Headers: 
    - Authorization: Bearer {JWT token}
    - Content-Type: multipart/form-data
  Form Data:
    - workspace_id: String (field)
    - audio: File (field, multipart)
  Response: { "audio_id": "UUID" }
  
  Implemented in: lib/features/record/data/audio_ingest_api.dart
  Used by: RecordNotifier.uploadFile()


Claude API Integration:
  Service: AnthropicService
  Endpoint: https://api.anthropic.com/v1/messages
  Model: claude-sonnet-4-5
  Authentication: x-api-key header
  Used for: Post-recording transcription/analysis in chat panel


================================================================================
ERROR HANDLING & RECOVERY
================================================================================

Common Errors & Solutions:

1. "Microphone permission denied"
   - Cause: Microphone permission not granted
   - Solution: User must enable in System Settings → Privacy & Security → Microphone

2. "Screen & System Audio Recording permission denied"
   - Cause: ScreenCaptureKit permission not granted
   - Solution: User must enable in System Settings → Privacy & Security → Screen & System Audio Recording

3. "No audio was captured"
   - Cause: File not created or empty
   - Solutions:
     * Check permission in System Settings
     * Fully quit and relaunch app
     * App must be in /Applications folder (not /tmp)

4. "Failed to start system audio capture"
   - Cause: SCStream creation failed or app not running from /Applications
   - Solution: Move app to /Applications folder

5. Upload fails with 400
   - Cause: Invalid audio file or workspace_id
   - Solution: Verify workspace is selected, audio file is valid

6. Upload fails with 401
   - Cause: JWT token expired or invalid
   - Solution: Re-authenticate user


================================================================================
TESTING CONSIDERATIONS
================================================================================

Unit Tests Needed:
  - RecordNotifier: State transitions, recording control
  - SystemAudioService: Method channel calls
  - AudioIngestApi: HTTP request/response handling
  - File validation before upload

Integration Tests:
  - Full recording → upload flow
  - Mixed audio mode (system + microphone)
  - Permission denial handling
  - Network error recovery

Manual Testing Checklist:
  ☐ Microphone recording (16 kHz, mono WAV output)
  ☐ System audio capture (requires ScreenCaptureKit permission)
  ☐ Mixed audio recording (both sources simultaneously)
  ☐ Audio file upload to backend
  ☐ Progress bar updates during upload
  ☐ Error messages for permission denials
  ☐ Pause/Resume (microphone only)
  ☐ Device selection (microphone)
  ☐ Workspace selection before recording
  ☐ File cleanup after upload
  ☐ macOS 13+ only (system audio)


================================================================================
PERFORMANCE & RESOURCE CONSIDERATIONS
================================================================================

Audio Memory Usage:
  - 16 kHz, 16-bit, mono = 32 kB/second = ~1.92 MB/minute
  - 1 hour recording ≈ 115 MB (uncompressed WAV)
  - Microphone buffer: 4096 samples ≈ 256ms latency

CPU Usage:
  - ScreenCaptureKit: Low impact (efficient hardware encoding)
  - AVAudioEngine: Low-moderate (real-time processing)
  - Audio mixing (vDSP): Vectorized, optimized

File I/O:
  - AVAssetWriter: Writes in real-time to disk
  - Temporary files cleaned up after mixing/upload
  - No caching in memory

Network:
  - Upload: Multipart form data with progress tracking
  - 1 minute (1.92 MB): ~10 seconds on 2 Mbps connection
  - Progress callback fires during upload


================================================================================
SECURITY CONSIDERATIONS
================================================================================

Permissions:
  - Microphone: NSMicrophoneUsageDescription in Info.plist
  - Screen capture: NSScreenCaptureUsageDescription in Info.plist
  - Both visible to user in System Settings

Data Storage:
  - API keys: Stored in flutter_secure_storage
  - JWT tokens: Stored in flutter_secure_storage
  - Audio files: Temporary directory (cleared by OS)
  - No audio cached permanently on device

API Security:
  - JWT authentication for workspace/upload endpoints
  - HTTPS for all requests
  - API key required for Claude integration

Privacy:
  - ScreenCaptureKit excludes app's own audio (excludesCurrentProcessAudio)
  - System audio includes all playing audio on system
  - Users can see app is recording (no silent recording)


================================================================================
BROWSER/PLATFORM COMPATIBILITY
================================================================================

Current Implementation:
  - macOS: Full support (microphone + system audio + mixing)
  - iOS: Microphone only (no ScreenCaptureKit)
  - Android: Microphone only (no ScreenCaptureKit equivalent)
  - Web: Limited (Web Audio API)
  - Windows: Microphone only (no ScreenCaptureKit)
  - Linux: Microphone only

Future Enhancement Paths:
  1. Android: Use MediaRecorder + system audio capture
  2. iOS: Use AVAudioEngine (limited system audio)
  3. Windows: Use WASAPI or similar for system audio


================================================================================
VERSION REQUIREMENTS
================================================================================

Flutter: >=3.19.0
Dart: >=3.3.0 <4.0.0
macOS: 13.0+ (ScreenCaptureKit requirement)
record package: 5.1.2+


================================================================================
FILE CHECKSUMS & SUMMARY
================================================================================

Total Audio/Recording-Related Files: 16

Dart Files (8):
  ✓ lib/features/record/data/system_audio_service.dart
  ✓ lib/features/record/data/audio_ingest_api.dart
  ✓ lib/features/record/data/anthropic_service.dart
  ✓ lib/features/record/presentation/record_notifier.dart
  ✓ lib/features/record/presentation/record_screen.dart
  ✓ lib/features/record/presentation/upload_modal.dart
  ✓ lib/features/record/presentation/chat_panel.dart
  ✓ lib/shared/providers/providers.dart

Swift Files (4):
  ✓ macos/Runner/SystemAudioRecorder.swift (Core implementation)
  ✓ macos/Runner/AppDelegate.swift (Method channel setup)
  ✓ macos/Runner/MainFlutterWindow.swift (Window config)
  ✓ macos/Runner/GeneratedPluginRegistrant.swift (Auto-generated)

Configuration Files (4):
  ✓ macos/Runner/Info.plist (Permissions)
  ✓ pubspec.yaml (Dependencies)
  ✓ pubspec.lock (Locked versions)
  ✓ analysis_options.yaml (Lint rules)

