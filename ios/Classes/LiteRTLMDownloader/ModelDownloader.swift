
import os.log
import CLiteRTLM
import UIKit
import TitaniumKit
/// Downloads and manages `.litertlm` model files on disk.
///
/// Observable for SwiftUI integration. Supports pause, resume, and cancel.
///
/// ```swift
/// let downloader = ModelDownloader()
///
/// // Download default model
/// await downloader.download(model: .gemma4E2B)
///
/// // Or download from custom URL
/// await downloader.download(from: myModelURL, fileName: "custom.litertlm")
///
/// // Check progress
/// print(downloader.progress) // 0.0 ... 1.0
///
/// // Use the model
/// if let path = downloader.modelPath(for: .gemma4E2B) {
///     let config = EngineConfiguration(modelPath: path)
/// }
/// ```
@Observable
public final class ModelDownloader: @unchecked Sendable {

    // MARK: - Public State

    /// Current download state.
    public private(set) var state: DownloadState = .idle

    /// Download progress (0.0 to 1.0).
    public private(set) var progress: Double = 0.0

    /// Bytes downloaded so far.
    public private(set) var downloadedBytes: Int64 = 0

    /// Total expected bytes (nil if unknown).
    public private(set) var totalBytes: Int64?

    // MARK: - Private

    private let lock = NSLock()
    private var downloadTask: URLSessionDownloadTask?
    private var session: URLSession?
    private var sessionDelegate: DownloadDelegate?
    private var resumeData: Data?
    private let logger = Logger(subsystem: "com.litertlm", category: "downloader")

    /// Base directory for storing models.
    public let modelsDirectory: URL

    // MARK: - Init

    public init(modelsDirectory: URL? = nil) {
        if let dir = modelsDirectory {
            self.modelsDirectory = dir
            NSLog("[DEBUG] ModelDownloader.init: custom directory = \(dir.path)")
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.modelsDirectory = appSupport.appendingPathComponent(
                "LiteRTLM/Models", isDirectory: true)
            NSLog("[DEBUG] ModelDownloader.init: default directory = \(self.modelsDirectory.path)")
        }

        try? ensureModelsDirectory()
    }

    /// Ensure the models directory exists on disk. Throws if creation fails.
    private func ensureModelsDirectory() throws {
        NSLog("[DEBUG] ModelDownloader.ensureModelsDirectory: path = \(modelsDirectory.path)")
        do {
            try FileManager.default.createDirectory(
                at: modelsDirectory, withIntermediateDirectories: true)
            NSLog("[DEBUG] ModelDownloader.ensureModelsDirectory: directory ready")
            logger.info("Models directory ready: \(self.modelsDirectory.path)")
        } catch {
            NSLog("[DEBUG] ModelDownloader.ensureModelsDirectory: FAILED - \(error.localizedDescription)")
            logger.error("Failed to create models directory: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Query

    /// Check if a model is already downloaded (and file size is plausible).
    public func isDownloaded(_ model: ModelInfo) -> Bool {
        let path = modelsDirectory.appendingPathComponent(model.fileName)
        guard FileManager.default.fileExists(atPath: path.path) else { return false }
        // If we know the expected size, reject files that are way too small (likely error pages)
        if let expected = model.expectedSize {
            let attrs = try? FileManager.default.attributesOfItem(atPath: path.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            if size < expected / 2 { return false }
        }
        return true
    }

    /// Check if a file exists by name.
    public func isDownloaded(fileName: String) -> Bool {
        FileManager.default.fileExists(
            atPath: modelsDirectory.appendingPathComponent(fileName).path)
    }

    /// Get the local path for a downloaded model.
    public func modelPath(for model: ModelInfo) -> URL? {
        let path = modelsDirectory.appendingPathComponent(model.fileName)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    /// Get the local path by file name.
    public func modelPath(fileName: String) -> URL? {
        let path = modelsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    // MARK: - Download

    /// Download a model from the registry.
    public func download(model: ModelInfo) async {
        await download(from: model.url, fileName: model.fileName, expectedSize: model.expectedSize)
    }

    /// Download a model from a custom URL.
    public func download(
        from url: URL,
        fileName: String? = nil,
        expectedSize: Int64? = nil
    ) async {
        let targetName = fileName ?? url.lastPathComponent
        NSLog("[DEBUG] ModelDownloader.download: url = \(url.absoluteString)")
        NSLog("[DEBUG] ModelDownloader.download: fileName param = \(fileName ?? "nil")")
        NSLog("[DEBUG] ModelDownloader.download: targetName = \(targetName)")
        NSLog("[DEBUG] ModelDownloader.download: modelsDirectory = \(modelsDirectory.path)")
        NSLog("[DEBUG] ModelDownloader.download: expectedSize = \(expectedSize?.description ?? "nil")")

        // Check if already downloaded
        if isDownloaded(fileName: targetName) {
            NSLog("[DEBUG] ModelDownloader.download: file already exists, skipping")
            state = .completed
            progress = 1.0
            return
        }

        totalBytes = expectedSize
        state = .downloading
        NSLog("[DEBUG] ModelDownloader.download: starting download task")

        let delegate = DownloadDelegate { [weak self] bytesWritten, totalWritten, expectedTotal in
            guard let self else { return }
            lock.lock()
            downloadedBytes = totalWritten
            if expectedTotal > 0 {
                totalBytes = expectedTotal
                progress = Double(totalWritten) / Double(expectedTotal)
            } else if let expected = expectedSize {
                progress = Double(totalWritten) / Double(expected)
            }
            lock.unlock()
        }

        sessionDelegate = delegate
        let urlSession = URLSession(
            configuration: .default, delegate: delegate, delegateQueue: nil)
        session = urlSession

        let task: URLSessionDownloadTask
        if let resumeData {
            task = urlSession.downloadTask(withResumeData: resumeData)
            self.resumeData = nil
        } else {
            task = urlSession.downloadTask(with: url)
        }
        downloadTask = task

        await withCheckedContinuation { continuation in
            delegate.completion = { [weak self] result in
                guard let self else {
                    continuation.resume()
                    return
                }
                switch result {
                case .success(let tempURL):
                    let dest = modelsDirectory.appendingPathComponent(targetName)
                    NSLog("[DEBUG] ModelDownloader: download complete, tempURL = \(tempURL.path)")
                    NSLog("[DEBUG] ModelDownloader: destination = \(dest.path)")
                    NSLog("[DEBUG] ModelDownloader: targetName = \(targetName)")
                    do {
                        // Ensure destination directory exists
                        try ensureModelsDirectory()
                        NSLog("[DEBUG] ModelDownloader: destination directory exists = \(FileManager.default.fileExists(atPath: dest.deletingLastPathComponent().path))")

                        if FileManager.default.fileExists(atPath: dest.path) {
                            NSLog("[DEBUG] ModelDownloader: removing existing file at \(dest.path)")
                            try FileManager.default.removeItem(at: dest)
                        }
                        NSLog("[DEBUG] ModelDownloader: attempting moveItem from \(tempURL.path) to \(dest.path)")
                        try FileManager.default.moveItem(at: tempURL, to: dest)
                        state = .completed
                        progress = 1.0
                        logger.info("Model downloaded to \(dest.path)")
                        NSLog("[DEBUG] ModelDownloader: move SUCCESS")
                    } catch {
                        let errorMsg = "Failed to move file: \(error.localizedDescription) (from \(tempURL.path) to \(dest.path))"
                        state = .failed(errorMsg)
                        logger.error("Move failed: \(errorMsg)")
                        NSLog("[DEBUG] ModelDownloader: move FAILED - \(errorMsg)")
                    }
                case .failure(let error):
                    if (error as NSError).code == NSURLErrorCancelled {
                        // Paused or cancelled — don't set failed
                        if state != .paused {
                            state = .idle
                        }
                    } else {
                        state = .failed(error.localizedDescription)
                        logger.error("Download failed: \(error.localizedDescription)")
                    }
                }
                continuation.resume()
            }
            task.resume()
        }
    }

    // MARK: - Control

    /// Pause the active download (resume data is preserved).
    public func pause() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] data in
            self?.lock.lock()
            self?.resumeData = data
            self?.state = .paused
            self?.lock.unlock()
        })
    }

    /// Cancel the download and discard resume data.
    public func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        resumeData = nil
        state = .idle
        progress = 0
        downloadedBytes = 0
        totalBytes = nil
    }

    /// Delete a downloaded model from disk.
    public func deleteModel(_ model: ModelInfo) throws {
        try deleteModel(fileName: model.fileName)
    }

    /// Delete a model file by name.
    public func deleteModel(fileName: String) throws {
        let path = modelsDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
        state = .idle
        progress = 0
    }
}

// MARK: - URLSession Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {

    let onProgress: @Sendable (Int64, Int64, Int64) -> Void
    nonisolated(unsafe) var completion: ((Result<URL, Error>) -> Void)?
    private let completionLock = NSLock()

    init(onProgress: @escaping @Sendable (Int64, Int64, Int64) -> Void) {
        self.onProgress = onProgress
    }

    /// Call completion at most once, preventing race between didFinish and didCompleteWithError
    private func complete(with result: Result<URL, Error>) {
        completionLock.lock()
        defer { completionLock.unlock() }
        guard let completion = completion else { return }
        self.completion = nil
        completion(result)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Pass the system temp URL directly – download() moves it synchronously
        // This avoids an unnecessary 2GB+ intermediate copy
        NSLog("[DEBUG] DownloadDelegate: didFinishDownloadingTo = \(location.path)")
        complete(with: .success(location))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            complete(with: .failure(error))
        }
    }
}
