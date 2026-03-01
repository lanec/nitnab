import Foundation
import SQLite3

print(" NitNab Diagnostic Tool")
print("========================\n")

// Database path
let homeDir = FileManager.default.homeDirectoryForCurrentUser
let containerPath = homeDir
    .appendingPathComponent("Library")
    .appendingPathComponent("Mobile Documents")
    .appendingPathComponent("iCloud~com~apple~CloudDocs")
    .appendingPathComponent("NitNab")

let dbPath = containerPath.appendingPathComponent("nitnab.db")
let semaphore = DispatchSemaphore(value: 0)

// Request authorization first
SFSpeechRecognizer.requestAuthorization { status in
    print("Authorization status: \(status.rawValue)")
    
    if status == .authorized {
        print("✅ Permission granted!\n")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.uppercased() == "WAV" }
            
            print("Found \(files.count) WAV files\n")
            
            for (index, file) in files.enumerated() {
                print("[\(index + 1)/\(files.count)] \(file.lastPathComponent)")
                
                let locale = Locale(identifier: "en-US")
                guard let recognizer = SFSpeechRecognizer(locale: locale) else {
                    print("  ❌ Recognizer not available\n")
                    continue
                }
                
                let request = SFSpeechURLRecognitionRequest(url: file)
                request.shouldReportPartialResults = false
                
                let taskSemaphore = DispatchSemaphore(value: 0)
                var transcriptText = ""
                
                recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        print("  ❌ Error: \(error.localizedDescription)")
                        taskSemaphore.signal()
                        return
                    }
                    
                    if let result = result, result.isFinal {
                        transcriptText = result.bestTranscription.formattedString
                        taskSemaphore.signal()
                    }
                }
                
                taskSemaphore.wait()
                
                if !transcriptText.isEmpty {
                    // Save to markdown
                    let baseName = (file.lastPathComponent as NSString).deletingPathExtension
                    let outputURL = transcriptsDir.appendingPathComponent("\(baseName).md")
                    
                    let markdown = """
                    # Transcription: \(file.lastPathComponent)
                    
                    **Date**: \(Date())
                    **Source**: \(file.lastPathComponent)
                    **Word Count**: \(transcriptText.split(separator: " ").count) words
                    
                    ---
                    
                    ## Transcript
                    
                    \(transcriptText)
                    
                    ---
                    
                    *Transcribed by NitNab*
                    """
                    
                    try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
                    print("  ✅ Saved: \(outputURL.lastPathComponent)")
                    print("  📄 \(transcriptText.prefix(80))...\n")
                }
            }
            
            print("\n✅ All done! Check the TRANSCRIPTS folder.")
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    } else {
        print("❌ Permission denied. Please enable Speech Recognition in System Settings.")
    }
    
    semaphore.signal()
}

semaphore.wait()
