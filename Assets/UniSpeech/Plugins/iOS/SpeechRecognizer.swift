import Foundation
import Speech



@objcMembers public class SpeechRecognizer : NSObject {
    public static let sharedInstance: SpeechRecognizer = SpeechRecognizer()

    public var _unitySendMessageGameObjectName: String = "SpeechRecognizer"
    public var unitySendMessageGameObjectName: String {
        get {
            return _unitySendMessageGameObjectName
        }
        set {
            _unitySendMessageGameObjectName = newValue
        }
    }

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private override init() {
        super.init()
        speechRecognizer.delegate = self
    }

    public func requestRecognizerAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.unitySendMessage("OnAuthorized")
                    break
                    
                case .denied:
                    // User denied access to speech recognition
                    self.unitySendMessage("OnUnauthorized")
                    
                case .restricted:
                    // Speech recognition restricted on this device
                    self.unitySendMessage("OnUnauthorized")
                    
                case .notDetermined:
                    // Speech recognition not yet authorized
                    self.unitySendMessage("OnUnauthorized")

                default:
                    self.unitySendMessage("OnUnauthorized")
                }
            }
        }
    }

    public func startRecord() -> Bool {
        if audioEngine.isRunning {
            return false
        }
        try! startRecording()
        return true
    }

    public func stopRecord() -> Bool {
        if !audioEngine.isRunning {
            return false
        }
        audioEngine.stop()
        recognitionRequest?.endAudio()
        return true
    }
    
    public func startRecording() throws {
        refreshTask()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSession.Category.record)
        try audioSession.setMode(AVAudioSession.Mode.measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.unitySendMessage("OnRecognized", message: result.bestTranscription.formattedString)
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.unitySendMessage("OnError", message: error.debugDescription)
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        try startAudioEngine()
    }

    public func refreshTask() {
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
    }
    
    private func startAudioEngine() throws {
        audioEngine.prepare()
        try audioEngine.start()
    }

    public func unitySendMessage(_ methodName: String, message: String = "") {
            let uf = UnityFramework()

            uf.sendMessageToGO(
            withName: self.unitySendMessageGameObjectName,
            functionName: methodName,
            message: message)
    }
}


extension SpeechRecognizer: SFSpeechRecognizerDelegate {
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if (available) {
            unitySendMessage("OnAvailable")
        } else {
            unitySendMessage("OnUnavailable")
        }
    }
}

