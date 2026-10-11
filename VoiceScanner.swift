import AVFoundation
import CoreML

class VoiceScanner: NSObject {
    private var recorder: AVAudioRecorder?
    private var url: URL?

    /// After recordFourSeconds finishes with nil, this says why, in plain words.
    var lastError: String?

    func recordFourSeconds(completion: @escaping ([Float]?) -> Void) {
        lastError = nil
        let session = AVAudioSession.sharedInstance()
        let handler: @Sendable (Bool) -> Void = { granted in
            DispatchQueue.main.async { self.startCapture(granted: granted, completion: completion) }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: handler)
        } else {
            session.requestRecordPermission(handler)
        }
    }

    private func startCapture(granted: Bool, completion: @escaping ([Float]?) -> Void) {
        let session = AVAudioSession.sharedInstance()
        guard granted else {
            self.lastError = "Microphone access is OFF for TrueView. Go to iPhone Settings → Privacy & Security → Microphone → TrueView and turn it ON."
            completion(nil); return
        }
        do {
            try session.setCategory(.playAndRecord, options: .defaultToSpeaker)
            try session.setActive(true)
        } catch {
            self.lastError = "The audio session wouldn't start. Fully close TrueView (swipe it away from the app switcher), reopen it, and try again."
            completion(nil); return
        }
        self.url = FileManager.default.temporaryDirectory.appendingPathComponent("clip.wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]
        guard let url = self.url,
              let rec = try? AVAudioRecorder(url: url, settings: settings) else {
            self.lastError = "The recorder wouldn't start. Fully close TrueView (swipe it away), reopen it, and try again."
            completion(nil); return
        }
        self.recorder = rec
        guard rec.record() else {
            self.lastError = "The recorder wouldn't start. Fully close TrueView (swipe it away), reopen it, and try again."
            completion(nil); return
        }
        // Record 4 seconds, stop explicitly, then let the file settle
        // before reading — no more racing the auto-stop timer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            rec.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(self.readSamples())
            }
        }
    }

    private func readSamples() -> [Float]? {
        guard let url, let file = try? AVAudioFile(forReading: url) else {
            lastError = "Couldn't open the recording. Fully close TrueView and try again."
            return nil
        }
        let count = Int(file.length)
        guard count > 8000, count <= 16000 * 10 else {
            lastError = "The microphone captured only silence. Make sure the mic isn't covered, speak up during the 4 seconds, and check no phone call is active."
            return nil
        }
        // Read into OUR OWN canonical format (16-bit int, 16 kHz, mono).
        // AVAudioFile converts automatically on read, so whatever dialect
        // the recorder actually wrote, this buffer always works.
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false),
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else {
            lastError = "Couldn't read the recording. Fully close TrueView and try again."
            return nil
        }
        do {
            try file.read(into: buf)
        } catch {
            lastError = "Couldn't read the recording. Fully close TrueView and try again."
            return nil
        }
        guard let ch = buf.int16ChannelData?[0] else {
            lastError = "Couldn't read the recording. Fully close TrueView and try again."
            return nil
        }
        var samples = (0..<count).map { Float(ch[$0]) / 32768.0 }
        if samples.count < 64000 { samples += [Float](repeating: 0, count: 64000 - samples.count) }
        return Array(samples.prefix(64000))
    }
}
