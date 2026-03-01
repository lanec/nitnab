//
//  DuplicateDetectionService.swift
//  NitNab
//
//  Service for detecting duplicate audio files using MD5 checksums
//

import Foundation
import CryptoKit

actor DuplicateDetectionService {
    static let shared = DuplicateDetectionService()
    
    private init() {}
    
    // MARK: - MD5 Checksum Calculation
    
    /// Calculate MD5 checksum for a file
    /// - Parameter url: URL of the file to checksum
    /// - Returns: MD5 checksum as hexadecimal string
    func calculateMD5(for url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    let hash = Insecure.MD5.hash(data: data)
                    let checksum = hash.map { String(format: "%02hhx", $0) }.joined()
                    continuation.resume(returning: checksum)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Calculate MD5 checksum for large files in chunks to avoid memory issues
    /// - Parameter url: URL of the file to checksum
    /// - Returns: MD5 checksum as hexadecimal string
    func calculateMD5Chunked(for url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let inputStream = InputStream(url: url) else {
                        throw DuplicateDetectionError.unableToOpenFile
                    }
                    
                    inputStream.open()
                    defer { inputStream.close() }
                    
                    var hash = Insecure.MD5()
                    let bufferSize = 1024 * 1024 // 1MB chunks
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                    defer { buffer.deallocate() }
                    
                    while inputStream.hasBytesAvailable {
                        let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
                        if bytesRead < 0 {
                            throw DuplicateDetectionError.readError
                        } else if bytesRead == 0 {
                            break
                        }
                        
                        let data = Data(bytes: buffer, count: bytesRead)
                        hash.update(data: data)
                    }
                    
                    let digest = hash.finalize()
                    let checksum = digest.map { String(format: "%02hhx", $0) }.joined()
                    continuation.resume(returning: checksum)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Calculate checksum for a file, automatically choosing method based on file size
    /// - Parameter url: URL of the file
    /// - Returns: MD5 checksum as hexadecimal string
    func calculateChecksum(for url: URL) async throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Use chunked method for files larger than 50MB
        if fileSize > 50 * 1024 * 1024 {
            return try await calculateMD5Chunked(for: url)
        } else {
            return try await calculateMD5(for: url)
        }
    }
    
    // MARK: - Duplicate Detection
    
    /// Check if a file is a duplicate based on checksum
    /// - Parameters:
    ///   - url: URL of the file to check
    ///   - existingChecksums: Set of existing checksums to compare against
    /// - Returns: Duplicate information (isDuplicate and checksum)
    func checkForDuplicate(url: URL, existingChecksums: Set<String>) async throws -> DuplicateCheckResult {
        let checksum = try await calculateChecksum(for: url)
        let isDuplicate = existingChecksums.contains(checksum)
        
        return DuplicateCheckResult(
            checksum: checksum,
            isDuplicate: isDuplicate
        )
    }
    
    /// Batch check multiple files for duplicates
    /// - Parameters:
    ///   - urls: Array of file URLs to check
    ///   - existingChecksums: Set of existing checksums
    /// - Returns: Dictionary mapping URLs to their duplicate check results
    func batchCheckForDuplicates(urls: [URL], existingChecksums: Set<String>) async -> [URL: DuplicateCheckResult] {
        var results: [URL: DuplicateCheckResult] = [:]
        
        for url in urls {
            do {
                let result = try await checkForDuplicate(url: url, existingChecksums: existingChecksums)
                results[url] = result
            } catch {
                // On error, we'll treat it as not a duplicate to allow the file through
                // Error checking duplicate — allow file through
                results[url] = DuplicateCheckResult(checksum: nil, isDuplicate: false)
            }
        }
        
        return results
    }
}

// MARK: - Data Models

struct DuplicateCheckResult {
    let checksum: String?
    let isDuplicate: Bool
}

enum DuplicateDetectionError: LocalizedError {
    case unableToOpenFile
    case readError
    
    var errorDescription: String? {
        switch self {
        case .unableToOpenFile:
            return "Unable to open file for checksum calculation"
        case .readError:
            return "Error reading file data"
        }
    }
}
