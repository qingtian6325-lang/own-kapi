import Foundation
#if canImport(Speech) && canImport(AVFoundation)
import Speech
import AVFoundation

/// 按住说话：SFSpeechRecognizer（zh-CN）实时转文字。
/// 权限按系统规范申请（语音识别 + 麦克风）；不可用时通过状态文案降级提示，打字不受影响。
@MainActor
public final class SpeechTranscriber: ObservableObject {
    @Published public var isRecording: Bool = false
    @Published public var partialText: String = ""
    @Published public var statusText: String = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    public init() {}

    public var isAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    public func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            statusText = "语音识别未授权，请在系统设置中允许，或直接打字"
            return false
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            statusText = "麦克风未授权，请在系统设置中允许，或直接打字"
            return false
        }
        return true
    }

    public func startRecording() {
        guard let recognizer, recognizer.isAvailable else {
            statusText = "语音识别当前不可用，请直接打字"
            return
        }
        cancelCurrentTask()
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusText = "录音启动失败，请直接打字"
            return
        }
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            statusText = "录音启动失败，请直接打字"
            return
        }

        partialText = ""
        statusText = "正在聆听，松开结束…"
        isRecording = true
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.partialText = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stopEngine()
                }
            }
        }
    }

    /// 停止录音并返回当前转写文字。
    @discardableResult
    public func stopRecording() -> String {
        recognitionRequest?.endAudio()
        stopEngine()
        let text = partialText
        statusText = ""
        return text
    }

    private func stopEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        isRecording = false
    }

    private func cancelCurrentTask() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        isRecording = false
    }
}
#endif
