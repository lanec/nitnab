//
//  TranscriptionViewModel.swift
//  NitNab
//

import Foundation
import SwiftUI

@available(macOS 26.0, *)
@MainActor
class TranscriptionViewModel: ObservableObject {
    @Published var jobs: [TranscriptionJob] = [] {
        didSet {
            guard !suppressJobsDidSet else { return }
            jobsByID = Dictionary(uniqueKeysWithValues: jobs.map { ($0.id, $0) })
            jobsVersion &+= 1
            syncSelectionAfterJobsMutation()
        }
    }
    @Published private(set) var selectedJobID: UUID?
    @Published var selectedJobIDs: Set<UUID> = []
    @Published private(set) var selectionSnapshot = SelectionSnapshot.empty
    @Published private(set) var jobsVersion: Int = 0
    @Published var selectedLocale: Locale = Locale(identifier: "en-US")
    @Published var isProcessing = false
    @Published var isTranscriptionAvailable: Bool = false
    
    // State for errors
    @Published var showingError = false
    @Published var errorMessage: String?
    @Published var showingDeleteConfirmation = false
    @Published var deleteConfirmationMessage = ""
    
    // State for company picker
    @Published var showingCompanyPicker = false
    @Published var pendingAudioFiles: [AudioFile] = []
    
    // State for duplicate detection
    @Published var showingDuplicateWarning = false
    @Published var duplicateFiles: [(url: URL, filename: String)] = []
    @Published var nonDuplicateFiles: [AudioFile] = []
    private var fileChecksums: [URL: String] = [:]  // Store checksums for pending files
    
    private let audioManager = AudioFileManager.shared
    private let transcriptionService = TranscriptionService.shared
    private let exportService = ExportService.shared
    private let persistenceService = PersistenceService.shared
    private let database = DatabaseService.shared
    private let aiService = AIService.shared
    private let memoryService = MemoryService.shared
    private let duplicateDetection = DuplicateDetectionService.shared
    private var pendingDeleteJobIDs: Set<UUID> = []
    private var jobsByID: [UUID: TranscriptionJob] = [:]
    private var suppressJobsDidSet = false
    
    @Published var supportedLocales: [Locale] = []

    struct SelectionSnapshot: Equatable {
        let ids: [UUID]
        let statusCounts: [TranscriptionStatus: Int]

        static let empty = SelectionSnapshot(ids: [], statusCounts: [:])

        var count: Int { ids.count }
        var isEmpty: Bool { ids.isEmpty }
    }

    struct DeleteValidationResult {
        let deletableIDs: Set<UUID>
        let blockedProcessingJobs: [TranscriptionJob]

        var isValid: Bool { !deletableIDs.isEmpty && blockedProcessingJobs.isEmpty }
    }

    struct DeleteFailure: Identifiable {
        let id: UUID
        let filename: String
        let reason: String
    }

    struct DeleteExecutionResult {
        let requestedCount: Int
        let trashedCount: Int
        let metadataOnlyCount: Int
        let deletedIDs: Set<UUID>
        let failures: [DeleteFailure]
    }

    var selectedJob: TranscriptionJob? {
        guard let selectedJobID else { return nil }
        return jobsByID[selectedJobID]
    }
    
    var canStartProcessing: Bool {
        !isProcessing && 
        !jobs.isEmpty && 
        jobs.contains(where: { $0.status == .pending }) &&
        isTranscriptionAvailable
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await checkAuthorization()
            await loadSupportedLocales()
            await initializeStorage()
            await loadJobsFromDatabase()
            await calculateMissingChecksums()
            await backfillMissingTranscripts()
        }
    }
    
    private func loadJobsFromDatabase() async {
        let loadedJobs = await database.loadAllJobs()
        await MainActor.run {
            self.setJobs(loadedJobs, invalidateFilter: true)
        }
    }

    private func withSuppressedJobsDidSet(_ operation: () -> Void) {
        suppressJobsDidSet = true
        operation()
        suppressJobsDidSet = false
    }

    private func setJobs(_ newJobs: [TranscriptionJob], invalidateFilter: Bool) {
        withSuppressedJobsDidSet {
            jobs = newJobs
        }
        jobsByID = Dictionary(uniqueKeysWithValues: newJobs.map { ($0.id, $0) })
        if invalidateFilter {
            jobsVersion &+= 1
        }
        syncSelectionAfterJobsMutation()
    }

    private func appendJob(_ job: TranscriptionJob, invalidateFilter: Bool) {
        withSuppressedJobsDidSet {
            jobs.append(job)
        }
        jobsByID[job.id] = job
        if invalidateFilter {
            jobsVersion &+= 1
        }
        syncSelectionAfterJobsMutation()
    }

    private func removeJobs(withIDs ids: Set<UUID>, invalidateFilter: Bool) {
        guard !ids.isEmpty else { return }
        withSuppressedJobsDidSet {
            jobs.removeAll { ids.contains($0.id) }
        }
        for id in ids {
            jobsByID.removeValue(forKey: id)
        }
        if invalidateFilter {
            jobsVersion &+= 1
        }
        syncSelectionAfterJobsMutation()
    }

    private func updateSelectionSnapshot(using selectedIDs: Set<UUID>) {
        var statusCounts: [TranscriptionStatus: Int] = [:]
        for id in selectedIDs {
            if let status = jobsByID[id]?.status {
                statusCounts[status, default: 0] += 1
            }
        }
        let orderedIDs = jobs.compactMap { selectedIDs.contains($0.id) ? $0.id : nil }
        let newSnapshot = SelectionSnapshot(ids: orderedIDs, statusCounts: statusCounts)
        if selectionSnapshot != newSnapshot {
            selectionSnapshot = newSnapshot
        }
    }
    
    /// Calculate checksums for existing files that don't have them
    private func calculateMissingChecksums() async {
        let jobsWithoutChecksums = jobs.filter { $0.fileChecksum == nil }
        
        guard !jobsWithoutChecksums.isEmpty else {
            return
        }
        
        var updatedCount = 0
        var errorCount = 0
        
        for job in jobsWithoutChecksums {
            // Try to find the audio file
            let audioFileURL = job.audioFile.url
            
            // Check if file exists at original path
            if FileManager.default.fileExists(atPath: audioFileURL.path) {
                do {
                    let checksum = try await duplicateDetection.calculateChecksum(for: audioFileURL)
                    
                    // Update job in memory
                    if jobsByID[job.id] != nil {
                        updateJob(job.id) { current in
                            current.fileChecksum = checksum
                        }

                        // Update database
                        var updatedJob = job
                        updatedJob.fileChecksum = checksum
                        try await database.updateJob(updatedJob)

                        updatedCount += 1
                    }
                } catch {
                    errorCount += 1
                }
            } else if let folderPath = job.folderPath {
                // Try to find file in folder path (iCloud location)
                let folderURL = URL(fileURLWithPath: folderPath)
                let audioFileName = job.audioFile.filename
                let iCloudAudioURL = folderURL.appendingPathComponent("Audio/\(audioFileName)")

                if FileManager.default.fileExists(atPath: iCloudAudioURL.path) {
                    do {
                        let checksum = try await duplicateDetection.calculateChecksum(for: iCloudAudioURL)

                        // Update job in memory
                        if jobsByID[job.id] != nil {
                            updateJob(job.id) { current in
                                current.fileChecksum = checksum
                            }

                            // Update database
                            var updatedJob = job
                            updatedJob.fileChecksum = checksum
                            try await database.updateJob(updatedJob)

                            updatedCount += 1
                        }
                    } catch {
                        errorCount += 1
                    }
                } else {
                    errorCount += 1
                }
            } else {
                errorCount += 1
            }
        }
    }
    
    /// Manually recalculate checksums for all files (can be called from UI)
    func recalculateAllChecksums() async {
        var updatedCount = 0
        var errorCount = 0
        
        for job in jobs {
            // Try to find the audio file
            let audioFileURL = job.audioFile.url
            
            // Check if file exists at original path
            if FileManager.default.fileExists(atPath: audioFileURL.path) {
                do {
                    let checksum = try await duplicateDetection.calculateChecksum(for: audioFileURL)
                    
                    // Only update if checksum changed
                    if job.fileChecksum != checksum {
                        // Update job in memory
                        if jobsByID[job.id] != nil {
                            updateJob(job.id) { current in
                                current.fileChecksum = checksum
                            }

                            // Update database
                            var updatedJob = job
                            updatedJob.fileChecksum = checksum
                            try await database.updateJob(updatedJob)

                            updatedCount += 1
                        }
                    }
                } catch {
                    errorCount += 1
                }
            } else if let folderPath = job.folderPath {
                // Try to find file in folder path (iCloud location)
                let folderURL = URL(fileURLWithPath: folderPath)
                let audioFileName = job.audioFile.filename
                let iCloudAudioURL = folderURL.appendingPathComponent("Audio/\(audioFileName)")
                
                if FileManager.default.fileExists(atPath: iCloudAudioURL.path) {
                    do {
                        let checksum = try await duplicateDetection.calculateChecksum(for: iCloudAudioURL)
                        
                        // Only update if checksum changed
                        if job.fileChecksum != checksum {
                            // Update job in memory
                            if jobsByID[job.id] != nil {
                                updateJob(job.id) { current in
                                    current.fileChecksum = checksum
                                }

                                // Update database
                                var updatedJob = job
                                updatedJob.fileChecksum = checksum
                                try await database.updateJob(updatedJob)

                                updatedCount += 1
                            }
                        }
                    } catch {
                        errorCount += 1
                    }
                }
            }
        }
        
    }
    
    /// Backfill transcript files for existing completed jobs that don't have them
    private func backfillMissingTranscripts() async {
        // Only check completed jobs with results
        let completedJobsWithResults = jobs.filter { 
            $0.status == .completed && $0.result != nil && $0.folderPath != nil
        }
        
        guard !completedJobsWithResults.isEmpty else {
            return
        }
        
        var backfilledCount = 0
        var errorCount = 0
        
        for job in completedJobsWithResults {
            // Check if transcript file exists
            guard let folderPath = job.folderPath else { continue }
            
            let folderURL = URL(fileURLWithPath: folderPath)
            let transcriptPath = folderURL.appendingPathComponent("Transcript/transcript.txt")
            
            // If transcript doesn't exist, save it
            if !FileManager.default.fileExists(atPath: transcriptPath.path) {
                do {
                    try await persistenceService.saveTranscript(for: job)
                    backfilledCount += 1
                } catch {
                    errorCount += 1
                    // Failed to backfill transcript
                }
            }
        }
        
        // Backfill complete
    }
    
    private func initializeStorage() async {
        // Set default autoPersist if not already set
        if UserDefaults.standard.object(forKey: "autoPersist") == nil {
            UserDefaults.standard.set(true, forKey: "autoPersist")
        }

        // getStoragePath() automatically defaults to iCloud, so just ensure directory exists
        if let _ = await persistenceService.getStoragePath() {
            try? await persistenceService.ensureStoragePathExists()
        }
    }
    
    func loadSupportedLocales() async {
        supportedLocales = await transcriptionService.getSupportedLocales()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() async {
        isTranscriptionAvailable = await transcriptionService.isAvailable()
        if !isTranscriptionAvailable {
            showError("Speech transcription is not available on this device.")
        }
    }
    
    // MARK: - File Management
    
    /// Simplified direct file addition - no company picker, just add files immediately
    func addFilesDirectly(_ urls: [URL]) {
        Task {
            for url in urls {
                do {
                    let createdJob = try await withSecurityScopedAccess(for: url) {
                        let audioFile = try await audioManager.validateAudioFile(at: url)
                        var job = TranscriptionJob(audioFile: audioFile)

                        if let checksum = try? await duplicateDetection.calculateChecksum(for: url) {
                            job.fileChecksum = checksum
                        }

                        let folderPath = try await copyAudioFileImmediately(for: job)
                        job.folderPath = folderPath

                        let folderName = URL(fileURLWithPath: folderPath).lastPathComponent
                        let audioPath = URL(fileURLWithPath: folderPath)
                            .appendingPathComponent("Audio/\(job.audioFile.filename)").path
                        try await database.insertTranscription(
                            job,
                            folderName: folderName,
                            audioPath: audioPath
                        )

                        return job
                    }

                    await MainActor.run {
                        appendJob(createdJob, invalidateFilter: true)
                    }
                } catch {
                    await MainActor.run {
                        showError("Failed to add file \(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func addFiles(_ urls: [URL]) {
        Task {
            var audioFiles: [AudioFile] = []
            var duplicates: [(url: URL, filename: String)] = []
            var knownChecksums = Set(jobs.compactMap { $0.fileChecksum })

            for url in urls {
                do {
                    let (audioFile, result) = try await withSecurityScopedAccess(for: url) {
                        let validated = try await audioManager.validateAudioFile(at: url)
                        let duplicateResult = try await duplicateDetection.checkForDuplicate(
                            url: url,
                            existingChecksums: knownChecksums
                        )
                        return (validated, duplicateResult)
                    }

                    if result.isDuplicate {
                        duplicates.append((url: url, filename: audioFile.filename))
                    } else {
                        audioFiles.append(audioFile)
                        if let checksum = result.checksum {
                            fileChecksums[url] = checksum
                            knownChecksums.insert(checksum)
                        }
                    }
                } catch {
                    await MainActor.run {
                        showError("Failed to add file '\(url.lastPathComponent)': \(error.localizedDescription)")
                    }
                }
            }

            if !duplicates.isEmpty {
                await MainActor.run {
                    duplicateFiles = duplicates
                    showingDuplicateWarning = true
                }
            }

            if !audioFiles.isEmpty {
                await MainActor.run {
                    pendingAudioFiles = audioFiles
                    nonDuplicateFiles = audioFiles
                    showingCompanyPicker = true
                }
            }
        }
    }
    
    func confirmFilesWithCompany(_ companyId: UUID?) {
        Task {
            let filesToProcess = pendingAudioFiles

            for audioFile in filesToProcess {
                do {
                    let createdJob = try await withSecurityScopedAccess(for: audioFile.url) {
                        var job = TranscriptionJob(audioFile: audioFile)
                        job.companyId = companyId

                        // Assign checksum if available
                        if let checksum = fileChecksums[audioFile.url] {
                            job.fileChecksum = checksum
                        }

                        let folderPath = try await copyAudioFileImmediately(for: job)
                        job.folderPath = folderPath

                        let folderName = URL(fileURLWithPath: folderPath).lastPathComponent
                        let audioPath = URL(fileURLWithPath: folderPath)
                            .appendingPathComponent("Audio/\(audioFile.filename)").path
                        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath)

                        return job
                    }

                    // Only add to UI if copy + insert succeeded
                    await MainActor.run {
                        appendJob(createdJob, invalidateFilter: true)
                    }
                } catch {
                    await MainActor.run {
                        showError("Failed to add file: \(error.localizedDescription)")
                    }
                    continue
                }
            }

            // Clear pending files and checksums
            pendingAudioFiles = []
            fileChecksums = [:]
        }
    }
    
    /// Copy audio file immediately when added (before transcription)
    /// Returns the folder path for the job
    private func copyAudioFileImmediately(for job: TranscriptionJob) async throws -> String {
        // Ensure storage path is configured
        var storagePath = await persistenceService.getStoragePath()
        
        if storagePath == nil {
            // Path not set yet, initialize it now
            if await persistenceService.isiCloudAvailable() {
                let containerID = "iCloud.\(Bundle.main.bundleIdentifier ?? "com.example.nitnab")"
                if let iCloudPath = FileManager.default.url(forUbiquityContainerIdentifier: containerID) {
                    let nitnabPath = iCloudPath.appendingPathComponent("Documents/NitNab")
                    await persistenceService.setStoragePath(nitnabPath)
                    try await persistenceService.ensureStoragePathExists()
                    storagePath = nitnabPath
                }
            }
        }
        
        guard let storagePath = storagePath else {
            throw PersistenceError.noStoragePath
        }
        
        // Create job folder with timestamp
        let timestamp = DateFormatter.filenameSafe.string(from: Date())
        let baseName = (job.audioFile.filename as NSString).deletingPathExtension
        let jobFolderName = "\(timestamp)_\(baseName)"
        let jobFolder = storagePath.appendingPathComponent(jobFolderName)
        
        // Create folder structure immediately
        let audioFolder = jobFolder.appendingPathComponent("Audio")
        let transcriptFolder = jobFolder.appendingPathComponent("Transcript")
        let aiSummaryFolder = jobFolder.appendingPathComponent("AI Summary")
        
        try FileManager.default.createDirectory(at: audioFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: transcriptFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: aiSummaryFolder, withIntermediateDirectories: true)
        
        // Copy audio file to Audio/ folder
        let audioDestination = audioFolder.appendingPathComponent(job.audioFile.filename)
        try await withSecurityScopedAccess(for: job.audioFile.url) {
            if !FileManager.default.fileExists(atPath: audioDestination.path) {
                try FileManager.default.copyItem(at: job.audioFile.url, to: audioDestination)
            }
        }

        // NOTE: Database insert is handled by the caller (addFilesDirectly or confirmFilesWithCompany)
        // to avoid double-insertion

        return jobFolder.path
    }
    
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Selection

    func setSelection(_ ids: Set<UUID>, primary: UUID? = nil) {
        let validIDs = ids.intersection(Set(jobsByID.keys))
        applySelection(validIDs, primary: primary)
    }

    func selectAllVisible(_ orderedIDs: [UUID]) {
        setSelection(Set(orderedIDs), primary: orderedIDs.first)
    }

    func clearSelection() {
        setSelection([], primary: nil)
    }

    func syncSelectionAfterJobsMutation(visibleIDs: [UUID]? = nil) {
        var validIDs = Set(jobsByID.keys)
        if let visibleIDs {
            validIDs.formIntersection(Set(visibleIDs))
        }
        applySelection(selectedJobIDs.intersection(validIDs), primary: selectedJobID)
    }

    func job(for id: UUID) -> TranscriptionJob? {
        jobsByID[id]
    }

    func jobs(for ids: [UUID]) -> [TranscriptionJob] {
        ids.compactMap { jobsByID[$0] }
    }

    private func applySelection(_ ids: Set<UUID>, primary: UUID?) {
        if selectedJobIDs != ids {
            selectedJobIDs = ids
        }

        if ids.count == 1 {
            let preferredID: UUID? = {
                if let primary, ids.contains(primary) { return primary }
                if let current = selectedJobID, ids.contains(current) { return current }
                return ids.first
            }()
            if selectedJobID != preferredID {
                selectedJobID = preferredID
            }
        } else if selectedJobID != nil {
            selectedJobID = nil
        }

        updateSelectionSnapshot(using: ids)
    }

    // MARK: - Delete Orchestration

    func requestDeleteForCurrentSelection() {
        requestDelete(ids: selectedJobIDs)
    }

    func requestDeleteForJob(_ job: TranscriptionJob) {
        requestDelete(ids: [job.id])
    }

    func requestDeleteForJobID(_ jobID: UUID) {
        requestDelete(ids: [jobID])
    }

    func requestDeleteFromContextMenu(for job: TranscriptionJob) {
        requestDeleteFromContextMenu(forJobID: job.id)
    }

    func requestDeleteFromContextMenu(forJobID jobID: UUID) {
        if selectedJobIDs.contains(jobID), !selectedJobIDs.isEmpty {
            requestDelete(ids: selectedJobIDs)
        } else {
            requestDelete(ids: [jobID])
        }
    }

    func cancelPendingDelete() {
        pendingDeleteJobIDs.removeAll()
        showingDeleteConfirmation = false
    }

    func confirmPendingDelete() {
        let ids = pendingDeleteJobIDs
        pendingDeleteJobIDs.removeAll()
        showingDeleteConfirmation = false

        guard !ids.isEmpty else { return }

        Task {
            let result = await deleteJobsToTrash(ids: ids)
            applyDeleteExecutionResult(result)
        }
    }

    func validateDeleteRequest(ids: Set<UUID>) -> DeleteValidationResult {
        let requestedIDs = ids.intersection(Set(jobsByID.keys))
        let blockedJobs = jobs.filter { requestedIDs.contains($0.id) && $0.status == .processing }
        let blockedIDs = Set(blockedJobs.map(\.id))
        let deletableIDs = requestedIDs.subtracting(blockedIDs)
        return DeleteValidationResult(deletableIDs: deletableIDs, blockedProcessingJobs: blockedJobs)
    }

    func deleteJobsToTrash(ids: Set<UUID>) async -> DeleteExecutionResult {
        let requestedIDs = ids.intersection(Set(jobsByID.keys))
        let jobsToDelete = jobs.filter { requestedIDs.contains($0.id) }

        var trashedCount = 0
        var metadataOnlyCount = 0
        var deletedIDs: Set<UUID> = []
        var failures: [DeleteFailure] = []

        for job in jobsToDelete {
            do {
                if let folderPath = job.folderPath, !folderPath.isEmpty {
                    let folderURL = URL(fileURLWithPath: folderPath)
                    if FileManager.default.fileExists(atPath: folderURL.path) {
                        _ = try FileManager.default.trashItem(at: folderURL, resultingItemURL: nil)
                        trashedCount += 1
                    } else {
                        metadataOnlyCount += 1
                    }
                } else {
                    metadataOnlyCount += 1
                }

                try await database.deleteJob(job.id)
                deletedIDs.insert(job.id)
            } catch {
                failures.append(DeleteFailure(id: job.id, filename: job.displayName, reason: error.localizedDescription))
            }
        }

        return DeleteExecutionResult(
            requestedCount: jobsToDelete.count,
            trashedCount: trashedCount,
            metadataOnlyCount: metadataOnlyCount,
            deletedIDs: deletedIDs,
            failures: failures
        )
    }

    private func requestDelete(ids: Set<UUID>) {
        let validation = validateDeleteRequest(ids: ids)

        if !validation.blockedProcessingJobs.isEmpty {
            let blockedNames = validation.blockedProcessingJobs.map(\.displayName)
            let shownNames = blockedNames.prefix(3).joined(separator: ", ")
            let suffix = blockedNames.count > 3 ? " and \(blockedNames.count - 3) more" : ""
            showError("Can't move files to Trash while processing: \(shownNames)\(suffix).")
            return
        }

        guard !validation.deletableIDs.isEmpty else { return }

        pendingDeleteJobIDs = validation.deletableIDs
        deleteConfirmationMessage = makeDeleteConfirmationMessage(for: validation.deletableIDs)
        showingDeleteConfirmation = true
    }

    private func makeDeleteConfirmationMessage(for ids: Set<UUID>) -> String {
        let selectedJobs = jobs.filter { ids.contains($0.id) }
        if selectedJobs.count == 1, let job = selectedJobs.first {
            return "Move \"\(job.displayName)\" to Trash?\n\nThis action can be undone from Trash."
        }
        return "Move \(selectedJobs.count) files to Trash?\n\nThis action can be undone from Trash."
    }

    private func applyDeleteExecutionResult(_ result: DeleteExecutionResult) {
        guard result.requestedCount > 0 else { return }

        if !result.deletedIDs.isEmpty {
            removeJobs(withIDs: result.deletedIDs, invalidateFilter: true)
        }

        let failedIDs = Set(result.failures.map(\.id))
        if !failedIDs.isEmpty {
            setSelection(failedIDs, primary: failedIDs.first)
            let summary = "\(result.deletedIDs.count) moved to Trash, \(result.failures.count) failed."
            showError(summary)
            return
        }

        syncSelectionAfterJobsMutation()
    }

    func selectJob(_ job: TranscriptionJob) {
        setSelection([job.id], primary: job.id)
    }
    
    func removeJob(_ job: TranscriptionJob) {
        removeJobs(withIDs: [job.id], invalidateFilter: true)
        
        // Delete from database and remove folder
        Task {
            do {
                // Delete from database
                try await database.deleteJob(job.id)

                // Delete folder from iCloud if it exists
                if let folderPath = job.folderPath {
                    let folderURL = URL(fileURLWithPath: folderPath)
                    if FileManager.default.fileExists(atPath: folderURL.path) {
                        try FileManager.default.removeItem(at: folderURL)
                    }
                }
            } catch {
                // Failed to delete job
            }
        }
    }
    
    func clearCompleted() {
        let jobsToRemove = jobs.filter { $0.status == .completed || $0.status == .failed }
        
        // Remove from memory
        removeJobs(withIDs: Set(jobsToRemove.map(\.id)), invalidateFilter: true)
        
        // Delete from database and folders
        Task {
            for job in jobsToRemove {
                do {
                    try await database.deleteJob(job.id)
                    
                    if let folderPath = job.folderPath {
                        let folderURL = URL(fileURLWithPath: folderPath)
                        if FileManager.default.fileExists(atPath: folderURL.path) {
                            try FileManager.default.removeItem(at: folderURL)
                        }
                    }
                } catch {
                    // Failed to delete job
                }
            }
        }
    }
    
    func clearAll() {
        let allJobs = jobs
        
        // Clear selection
        clearSelection()
        
        // Remove from memory
        setJobs([], invalidateFilter: true)
        
        // Delete all from database and folders
        Task {
            for job in allJobs {
                do {
                    try await database.deleteJob(job.id)
                    
                    if let folderPath = job.folderPath {
                        let folderURL = URL(fileURLWithPath: folderPath)
                        if FileManager.default.fileExists(atPath: folderURL.path) {
                            try FileManager.default.removeItem(at: folderURL)
                        }
                    }
                } catch {
                    // Failed to delete job
                }
            }
        }
    }
    
    // MARK: - Diagnostics & Cleanup
    
    /// Nuclear option: Delete everything and start fresh
    func nukeEverything() async {
        // Clear memory
        await MainActor.run {
            clearSelection()
            setJobs([], invalidateFilter: true)
            pendingAudioFiles.removeAll()
            fileChecksums.removeAll()
        }
        
        // Delete entire database
        do {
            try await database.deleteAllJobs()
        } catch {
            // Failed to clear database
        }
        
        // Delete all iCloud folders
        if let storagePath = await persistenceService.getStoragePath() {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: storagePath, includingPropertiesForKeys: nil)
                for item in contents where item.hasDirectoryPath {
                    try FileManager.default.removeItem(at: item)
                }
            } catch {
                // Failed to delete folders
            }
        }
    }
    
    /// Diagnostic: Print all database entries
    func printDatabaseDiagnostics() async {
        print("\n" + String(repeating: "=", count: 60))
        print("📊 DATABASE DIAGNOSTICS")
        print(String(repeating: "=", count: 60))
        
        let dbJobs = await database.loadAllJobs()
        
        print("\n📝 Total entries in database: \(dbJobs.count)")
        print("📝 Total jobs in memory: \(jobs.count)")
        print("📝 Total pending files: \(pendingAudioFiles.count)")
        print("📝 Total cached checksums: \(fileChecksums.count)")
        
        if !dbJobs.isEmpty {
            print("\n📋 Database Entries:")
            for (index, job) in dbJobs.enumerated() {
                print("\n  [\(index + 1)] \(job.displayName)")
                print("      ID: \(job.id.uuidString)")
                print("      Status: \(job.status.rawValue)")
                print("      Checksum: \(job.fileChecksum ?? "none")")
                print("      Folder: \(job.folderPath ?? "none")")
                print("      Created: \(job.createdAt)")
            }
        } else {
            print("\n  ✅ Database is empty")
        }
        
        // Check for orphaned folders
        if let storagePath = await persistenceService.getStoragePath() {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: storagePath, includingPropertiesForKeys: nil)
                let folders = contents.filter { $0.hasDirectoryPath }
                
                print("\n📁 iCloud Folders: \(folders.count)")
                for folder in folders {
                    print("      \(folder.lastPathComponent)")
                }
                
                // Check for orphans
                let folderNames = Set(folders.map { $0.lastPathComponent })
                let dbFolderNames = Set(dbJobs.compactMap { $0.folderPath }.map { URL(fileURLWithPath: $0).lastPathComponent })
                let orphanedFolders = folderNames.subtracting(dbFolderNames)
                
                if !orphanedFolders.isEmpty {
                    print("\n⚠️ ORPHANED FOLDERS (in iCloud but not in database):")
                    for folder in orphanedFolders {
                        print("      \(folder)")
                    }
                }
            } catch {
                print("\n❌ Failed to read iCloud folders: \(error)")
            }
        }
        
        print("\n" + String(repeating: "=", count: 60) + "\n")
    }
    
    // MARK: - Transcription
    
    // MARK: - Job Mutation Helpers

    /// Safely update a job by ID — avoids index invalidation after async operations.
    /// Set affectsFilter when fields that impact Advanced filtering/sorting are changed.
    private func updateJob(_ jobId: UUID, affectsFilter: Bool = false, _ transform: (inout TranscriptionJob) -> Void) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        withSuppressedJobsDidSet {
            transform(&jobs[idx])
        }
        jobsByID[jobId] = jobs[idx]

        if affectsFilter {
            jobsVersion &+= 1
        }

        if selectedJobIDs.contains(jobId) || selectedJobID == jobId {
            updateSelectionSnapshot(using: selectedJobIDs)
        }
    }

    /// Persist the latest in-memory job snapshot to the database by ID.
    private func persistJobToDatabase(jobId: UUID) {
        Task { @MainActor in
            guard let job = jobsByID[jobId] else { return }
            do {
                try await database.updateJob(job)
            } catch {
                // Failed to persist job
            }
        }
    }

    /// Run an operation while balancing security-scoped URL access.
    private func withSecurityScopedAccess<T>(for url: URL, operation: () async throws -> T) async throws -> T {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation()
    }

    func startProcessing() {
        guard canStartProcessing else { return }

        Task {
            isProcessing = true
            let pendingIds = jobs.filter { $0.status == .pending }.map { $0.id }
            for jobId in pendingIds {
                await processJob(id: jobId)
            }
            isProcessing = false
        }
    }

    private func processJob(id jobId: UUID) async {
        guard let job = jobsByID[jobId] else { return }

        updateJob(jobId) { $0.status = .processing }

        // Access the file URL with security scoped resource
        let url = job.audioFile.url
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Prepare audio file
            let audioURL = try await audioManager.prepareAudioForTranscription(audioFile: job.audioFile)

            // Get custom vocabulary if company is assigned
            var customVocabulary: [String] = []
            if let companyId = job.companyId {
                customVocabulary = await memoryService.buildVocabularyForCompany(companyId)
            }

            // Transcribe — real progress via SpeechTranscriber
            var result = try await transcriptionService.transcribe(
                audioURL: audioURL,
                locale: selectedLocale,
                customVocabulary: customVocabulary,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.updateJob(jobId) { $0.progress = progress }
                    }
                }
            )

            // Post-process with AI to fix misheard names
            if let companyId = job.companyId {
                result = try await correctNamesWithAI(transcript: result.fullTranscript, companyId: companyId, originalResult: result)
            }
            
            // Update job with result
            updateJob(jobId, affectsFilter: true) { j in
                j.status = .completed
                j.result = result
                j.completedAt = Date()
                j.progress = 1.0
            }

            // Save to database
            if let completedJob = jobsByID[jobId] {
                Task {
                    try? await database.updateJob(completedJob)
                }
            }
            
            // Auto-save transcript if enabled
            let autoPersistEnabled = UserDefaults.standard.bool(forKey: "autoPersist")

            if autoPersistEnabled, let savedJob = jobsByID[jobId] {
                Task {
                    do {
                        try await persistenceService.saveTranscript(for: savedJob)
                    } catch {
                        await MainActor.run {
                            self.showError("Failed to save transcript: \(error.localizedDescription)")
                        }
                    }
                }
            }

        } catch {
            // Handle error — look up by ID, not stale index
            let errorMsg = error.localizedDescription
            updateJob(jobId) { j in
                j.status = .failed
                j.error = errorMsg
            }

            // Persist error to database
            if let failedJob = jobsByID[jobId] {
                try? await database.updateJob(failedJob)
            }
        }
    }
    
    func cancelProcessing() {
        Task {
            await transcriptionService.cancelTranscription()

            let processingIds = jobs.filter { $0.status == .processing }.map { $0.id }
            for jobId in processingIds {
                updateJob(jobId) { $0.status = .cancelled }

                if let cancelledJob = jobsByID[jobId] {
                    do {
                        try await database.updateJob(cancelledJob)
                    } catch {
                        // Failed to save cancellation to database
                    }
                }
            }

            isProcessing = false
        }
    }
    
    func retryJob(_ job: TranscriptionJob) {
        guard jobsByID[job.id] != nil else { return }

        updateJob(job.id, affectsFilter: true) { current in
            current.status = .pending
            current.progress = 0
            current.error = nil
            current.result = nil
            current.completedAt = nil
        }
        persistJobToDatabase(jobId: job.id)
    }
    
    // MARK: - Export
    
    func exportTranscription(_ job: TranscriptionJob, format: ExportFormat) {
        guard let result = job.result else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: format.fileExtension)!]
        panel.nameFieldStringValue = "\(job.audioFile.filename)_transcript.\(format.fileExtension)"
        panel.message = "Export transcription as \(format.rawValue)"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            Task {
                do {
                    try await self.exportService.export(result: result, format: format, to: url)
                } catch {
                    self.showError("Failed to export: \(error.localizedDescription)")
                }
            }
        }
    }

    func exportTranscription(jobID: UUID, format: ExportFormat) {
        guard let job = jobsByID[jobID] else { return }
        exportTranscription(job, format: format)
    }
    
    func copyToClipboard(_ job: TranscriptionJob) {
        guard let result = job.result else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result.fullTranscript, forType: .string)
    }

    func copyToClipboard(jobID: UUID) {
        guard let job = jobsByID[jobID] else { return }
        copyToClipboard(job)
    }
    
    // MARK: - File Management Actions
    
    func openJobFolder(_ job: TranscriptionJob) {
        guard let folderPath = job.folderPath else {
            showError("Folder path not available for this file")
            return
        }
        
        let url = URL(fileURLWithPath: folderPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    func openJobFolder(jobID: UUID) {
        guard let job = jobsByID[jobID] else { return }
        openJobFolder(job)
    }
    
    /// Rename a job (used by inline editing)
    func renameJob(_ job: TranscriptionJob, to newName: String) {
        guard jobsByID[job.id] != nil else { return }
        
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        updateJob(job.id, affectsFilter: true) { current in
            current.customName = trimmedName
        }
        persistJobToDatabase(jobId: job.id)
    }

    func renameJob(jobID: UUID, to newName: String) {
        guard let job = jobsByID[jobID] else { return }
        renameJob(job, to: newName)
    }
    
    func showRenameDialog(for job: TranscriptionJob) {
        guard jobsByID[job.id] != nil else { return }
        
        let alert = NSAlert()
        alert.messageText = "Rename File"
        alert.informativeText = "Enter a new name for this transcription"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = job.customName ?? job.audioFile.filename
        alert.accessoryView = textField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespaces)
            if !newName.isEmpty {
                renameJob(job, to: newName)
            }
        }
    }

    func showRenameDialog(forJobID jobID: UUID) {
        guard let job = jobsByID[jobID] else { return }
        showRenameDialog(for: job)
    }
    
    func showDescriptionDialog(for job: TranscriptionJob) {
        guard jobsByID[job.id] != nil else { return }
        
        let alert = NSAlert()
        alert.messageText = "Edit Description"
        alert.informativeText = "Add a description for this transcription"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        textView.string = job.description ?? ""
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 13)
        
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        
        alert.accessoryView = scrollView
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let desc = textView.string.trimmingCharacters(in: .whitespaces)
            updateJob(job.id, affectsFilter: true) { current in
                current.description = desc.isEmpty ? nil : desc
            }
            persistJobToDatabase(jobId: job.id)
        }
    }

    func showDescriptionDialog(forJobID jobID: UUID) {
        guard let job = jobsByID[jobID] else { return }
        showDescriptionDialog(for: job)
    }
    
    func assignCompany(_ companyId: UUID?, to job: TranscriptionJob) {
        guard jobsByID[job.id] != nil else { return }

        updateJob(job.id) { current in
            current.companyId = companyId
        }
        persistJobToDatabase(jobId: job.id)
    }

    func assignCompany(_ companyId: UUID?, toJobID jobID: UUID) {
        guard let job = jobsByID[jobID] else { return }
        assignCompany(companyId, to: job)
    }

    func retryJob(jobID: UUID) {
        guard let job = jobsByID[jobID] else { return }
        retryJob(job)
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    // MARK: - AI Name Correction
    
    /// Use AI to correct misheard names in transcription
    private func correctNamesWithAI(transcript: String, companyId: UUID, originalResult: TranscriptionResult) async throws -> TranscriptionResult {
        // Get people from the company
        let people = await memoryService.getPeopleForCompany(companyId)
        
        guard !people.isEmpty else {
            return originalResult
        }
        
        // Use AI to identify and correct names
        let correctedText = try await aiService.correctMisheardNames(
            transcript: transcript,
            knownPeople: people
        )
        
        // If text changed, create updated result
        if correctedText != transcript {
            // Create new result with corrected text
            let correctedResult = TranscriptionResult(
                fullTranscript: correctedText,
                segments: originalResult.segments,
                language: originalResult.language,
                confidence: originalResult.confidence
            )
            
            return correctedResult
        }
        
        return originalResult
    }
}
