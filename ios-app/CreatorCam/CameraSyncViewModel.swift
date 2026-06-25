import Foundation
import SwiftUI
import UIKit
import NetworkExtension
import Photos
import Combine


struct CreatorPhoto: Codable, Identifiable, Hashable {
    let id: Int
    let filename: String
    let size: Int
    let url: String
}

struct CreatorVideo: Codable, Identifiable, Hashable {
    let id: Int
    let filename: String
    let size: Int
    let url: String
}

struct CameraStatus: Codable {
    let ready: Bool
    let sd_ok: Bool
    let camera_ok: Bool
    let recording: Bool?
    let latest_id: Int
    let next_id: Int
    let latest_video_id: Int?
    let next_video_id: Int?
}

private struct PhotoSyncSummary {
    let downloaded: Int
    let skippedOlder: Int
    let remainingNew: Int
    let failed: Int
}

// MARK: - Connection State

enum ConnectionState: Equatable {
    case idle
    case joining
    case checking
    case connected(latestId: Int)
    case offline

    var title: String {
        switch self {
        case .idle:
            return "Ready"
        case .joining:
            return "Joining Wi-Fi..."
        case .checking:
            return "Checking camera..."
        case .connected:
            return "Camera connected"
        case .offline:
            return "Camera not connected"
        }
    }

    var dotColor: Color {
        switch self {
        case .connected:
            return .green
        case .joining, .checking:
            return .orange
        case .offline:
            return .red
        case .idle:
            return .gray
        }
    }
}

// MARK: - Gallery Tab

enum GalleryTab: String, CaseIterable, Identifiable {
    case photos = "Photos"
    case videos = "Videos"

    var id: String { rawValue }
}

// MARK: - ViewModel

@MainActor
final class CreatorCamViewModel: ObservableObject {
    @Published var photos: [CreatorPhoto] = []
    @Published var videos: [CreatorVideo] = []

    @Published var localFiles: [Int: URL] = [:]
    @Published var localVideoFiles: [Int: URL] = [:]

    @Published var hiddenPhotoIDs: Set<Int> = []
    @Published var hiddenVideoIDs: Set<Int> = []

    @Published var connectionState: ConnectionState = .idle
    @Published var isLoading = false
    @Published var isJoiningWiFi = false
    @Published var isSavingToPhotos = false
    @Published var isSavingVideoToPhotos = false
    @Published var isConvertingVideo = false
    @Published var isEnhancingLibrary = false
    @Published var imageRefreshID = 0

    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var syncProgressText: String?

    private var cameraWiFiSSID: String {
        didSet {
            UserDefaults.standard.set(cameraWiFiSSID, forKey: cameraWiFiSSIDKey)
        }
    }

    private var cameraWiFiPassword: String {
        didSet {
            UserDefaults.standard.set(cameraWiFiPassword, forKey: cameraWiFiPasswordKey)
        }
    }

    private let defaultCameraHost = "192.168.10.1"
    private let maxPhotosPerSync = 12
    private let maxVideosPerSync = 1
    private let syncVideosAutomatically = true

    private let cameraWiFiSSIDKey = "CreatorCam.cameraWiFiSSID"
    private let cameraWiFiPasswordKey = "CreatorCam.cameraWiFiPassword"

    private let lastSyncedIdKey = "CreatorCam.lastSyncedId"
    private let lastSyncedVideoIdKey = "CreatorCam.lastSyncedVideoId"

    private let galleryIndexKey = "CreatorCam.galleryIndex"
    private let videoIndexKey = "CreatorCam.videoIndex"

    private let hiddenPhotoIDsKey = "CreatorCam.hiddenPhotoIDs"
    private let hiddenVideoIDsKey = "CreatorCam.hiddenVideoIDs"

    private var lastSyncedId: Int {
        get { UserDefaults.standard.integer(forKey: lastSyncedIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncedIdKey) }
    }

    private var lastSyncedVideoId: Int {
        get { UserDefaults.standard.integer(forKey: lastSyncedVideoIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncedVideoIdKey) }
    }

    private var baseURL: URL {
        URL(string: "http://\(defaultCameraHost)")!
    }

    private var photosFolderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("CreatorCamPhotos", isDirectory: true)
    }
    
    private var enhancedPhotosFolderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("CreatorCamEnhancedPhotos", isDirectory: true)
    }

    private var videosFolderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("CreatorCamVideos", isDirectory: true)
    }

    private func rawVideoURL(for video: CreatorVideo) -> URL {
        videosFolderURL.appendingPathComponent(video.filename)
    }

    private func mp4Filename(for video: CreatorVideo) -> String {
        let base = (video.filename as NSString).deletingPathExtension
        return "\(base).mp4"
    }

    private func mp4VideoURL(for video: CreatorVideo) -> URL {
        videosFolderURL.appendingPathComponent(mp4Filename(for: video))
    }

    init() {
        cameraWiFiSSID = UserDefaults.standard.string(forKey: cameraWiFiSSIDKey) ?? "your_camera_ssid"
        cameraWiFiPassword = UserDefaults.standard.string(forKey: cameraWiFiPasswordKey) ?? "your_camera_password"

        createPhotosFolderIfNeeded()
        createEnhancedPhotosFolderIfNeeded()
        createVideosFolderIfNeeded()

        loadHiddenPhotoIDs()
        loadHiddenVideoIDs()

        loadGalleryIndex()
        loadVideoIndex()

        loadLocalFiles()
        loadLocalVideoFiles()
    }

    var savedCountText: String {
        "\(photos.count)"
    }

    var videoCountText: String {
        "\(videos.count)"
    }

    var pendingText: String {
        guard case .connected(let latestId) = connectionState else {
            return "—"
        }

        let pending = max(0, latestId - lastSyncedId)
        return "\(pending)"
    }

    var statusSubtitle: String {
        if photos.isEmpty && videos.isEmpty {
            return "No memories synced yet"
        }

        return "\(photos.count) photo\(photos.count == 1 ? "" : "s") · \(videos.count) video\(videos.count == 1 ? "" : "s")"
    }

    // MARK: - Wi-Fi

    func joinCameraWiFiFromApp() async throws {
        let ssid = cameraWiFiSSID.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = cameraWiFiPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !ssid.isEmpty else {
            throw NSError(
                domain: "CreatorCam",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Wi-Fi name is empty."]
            )
        }

        isJoiningWiFi = true
        connectionState = .joining
        defer { isJoiningWiFi = false }

        let configuration: NEHotspotConfiguration

        if password.isEmpty {
            configuration = NEHotspotConfiguration(ssid: ssid)
        } else {
            configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        }

        configuration.joinOnce = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NEHotspotConfigurationManager.shared.apply(configuration) { error in
                if let error {
                    let nsError = error as NSError

                    if nsError.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    // MARK: - Camera API

    @discardableResult
    func checkConnection() async -> Bool {
        // Important:
        // Do NOT skip this while isLoading is true.
        // connectAndSync() sets isLoading = true before calling checkConnection().
        // If we return early here, the UI can stay stuck on "Joining Wi-Fi..."
        // and the app tries to sync without confirming the camera is reachable.
        connectionState = .checking
        errorMessage = nil

        do {
            let status: CameraStatus = try await getJSON(path: "/status.json")

            if status.ready || status.sd_ok || status.camera_ok {
                connectionState = .connected(latestId: status.latest_id)
                return true
            } else {
                connectionState = .offline
                errorMessage = "Camera replied, but SD/camera is not ready."
                return false
            }
        } catch {
            connectionState = .offline
            errorMessage = "Cannot reach PocketCam. Make sure iPhone is connected to the camera network."
            print("checkConnection error:", error)
            return false
        }
    }

    func connectAndSync() async {
        guard !isLoading && !isJoiningWiFi else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        syncProgressText = "Preparing sync..."
        defer {
            isLoading = false
            syncProgressText = nil
        }

        do {
            try await joinCameraWiFiFromApp()
        } catch {
            print("Wi-Fi join error:", error)
            errorMessage = "Could not auto-join the camera network. Open iPhone Settings, connect to the camera network, then tap Sync again."
        }

        let connected = await checkConnection()

        guard connected else {
            return
        }

        do {
            syncProgressText = "Checking new photos..."
            let photoSync = try await syncNewPhotos()

            var videoDownloaded = 0
            if syncVideosAutomatically {
                // Videos are optional and can be large, so they must never block photo sync.
                syncProgressText = "Checking new videos..."
                do {
                    videoDownloaded = try await syncNewVideos()
                } catch {
                    videoDownloaded = 0
                    print("video sync skipped:", error)
                }
            }

            connectionState = .connected(latestId: lastSyncedId)

            if photoSync.downloaded > 0 || photoSync.skippedOlder > 0 || photoSync.remainingNew > 0 || photoSync.failed > 0 || videoDownloaded > 0 {
                var message: String
                if photoSync.downloaded == 0 && videoDownloaded == 0 {
                    message = "Gallery checked ✅"
                } else if videoDownloaded > 0 {
                    message = "Synced \(photoSync.downloaded) photo\(photoSync.downloaded == 1 ? "" : "s") and \(videoDownloaded) video\(videoDownloaded == 1 ? "" : "s") ✅"
                } else {
                    message = "Synced \(photoSync.downloaded) photo\(photoSync.downloaded == 1 ? "" : "s") ✅"
                }

                if photoSync.skippedOlder > 0 {
                    message += " Skipped \(photoSync.skippedOlder) older photo\(photoSync.skippedOlder == 1 ? "" : "s") to keep sync fast."
                } else if photoSync.remainingNew > 0 {
                    message += " \(photoSync.remainingNew) more photo\(photoSync.remainingNew == 1 ? "" : "s") waiting. Tap Sync again."
                }

                if photoSync.failed > 0 {
                    message += " \(photoSync.failed) photo\(photoSync.failed == 1 ? "" : "s") could not download this time."
                }

                successMessage = message
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                successMessage = "Gallery is up to date ✅"
            }
        } catch {
            errorMessage = "Photo sync failed. \(friendlySyncError(error))"
            print("photo sync error:", error)
        }
    }

    private func syncNewPhotos() async throws -> PhotoSyncSummary {
        let cameraStatus: CameraStatus? = try? await getJSON(path: "/status.json")
        let latestRemoteIdFromStatus = cameraStatus?.latest_id ?? 0

        var requestSince = lastSyncedId
        var skippedBeforeWindow = 0

        // Backward-compatible fast sync:
        // older firmware ignores limit/latest, but it already supports since.
        // So when the SD has a large backlog, ask for only the newest small window.
        if latestRemoteIdFromStatus > 0 {
            let pendingRemoteCount = latestRemoteIdFromStatus - lastSyncedId
            if pendingRemoteCount > maxPhotosPerSync {
                requestSince = max(lastSyncedId, latestRemoteIdFromStatus - maxPhotosPerSync)
                skippedBeforeWindow = max(0, requestSince - lastSyncedId)
            }
        }

        let photoListPath = "/photos.json?since=\(requestSince)&limit=\(maxPhotosPerSync)"
        let remotePhotos: [CreatorPhoto] = try await getJSON(path: photoListPath)
        let sorted = remotePhotos.sorted { $0.id < $1.id }

        guard !sorted.isEmpty else {
            if requestSince > lastSyncedId {
                lastSyncedId = requestSince
            }
            let remainingNew = latestRemoteIdFromStatus > 0 ? max(0, latestRemoteIdFromStatus - lastSyncedId) : 0
            return PhotoSyncSummary(downloaded: 0, skippedOlder: skippedBeforeWindow, remainingNew: remainingNew, failed: 0)
        }

        let isFirstLargeSync = lastSyncedId == 0 && sorted.count > maxPhotosPerSync
        let photosForThisSync: [CreatorPhoto]
        let skippedOlder: Int

        if isFirstLargeSync {
            photosForThisSync = Array(sorted.suffix(maxPhotosPerSync))
            skippedOlder = sorted.count - photosForThisSync.count
        } else {
            photosForThisSync = Array(sorted.prefix(maxPhotosPerSync))
            skippedOlder = 0
        }

        let remainingNew = max(0, sorted.count - photosForThisSync.count - skippedOlder)

        var downloaded = 0
        var failed = 0
        var nextLastSyncedId = max(lastSyncedId, requestSince)

        var updatedPhotosByID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        var updatedLocalFiles = localFiles

        for (index, photo) in photosForThisSync.enumerated() {
            if hiddenPhotoIDs.contains(photo.id) {
                nextLastSyncedId = max(nextLastSyncedId, photo.id)
                continue
            }

            let originalURL = photosFolderURL.appendingPathComponent(photo.filename)
            let processedURL = mostRecentExistingProcessedPhotoURL(for: photo)

            let originalExists = await fileExists(at: originalURL)

            if !originalExists {
                syncProgressText = "Downloading photo \(index + 1)/\(photosForThisSync.count) (#\(photo.id))..."
                do {
                    let data = try await getRawData(path: photo.url)
                    guard !data.isEmpty else {
                        throw NSError(
                            domain: "CreatorCamSync",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Photo #\(photo.id) downloaded as an empty file."]
                        )
                    }

                    try await writeData(data, to: originalURL)
                    downloaded += 1
                } catch {
                    failed += 1
                    print("photo download skipped #\(photo.id):", error)
                }
            }

            if let processedURL {
                updatedLocalFiles[photo.id] = processedURL
            } else if await fileExists(at: originalURL) {
                updatedLocalFiles[photo.id] = originalURL
            } else {
                continue
            }

            updatedPhotosByID[photo.id] = photo
            nextLastSyncedId = max(nextLastSyncedId, photo.id)
        }

        if skippedOlder > 0, let latestRemoteId = sorted.last?.id {
            nextLastSyncedId = max(nextLastSyncedId, latestRemoteId)
        }

        let visiblePhotos = updatedPhotosByID.values
            .filter { !hiddenPhotoIDs.contains($0.id) }
            .sorted { $0.id > $1.id }

        photos = visiblePhotos
        localFiles = updatedLocalFiles
        lastSyncedId = nextLastSyncedId

        saveGalleryIndex()

        let remainingNewFromStatus = latestRemoteIdFromStatus > 0 ? max(0, latestRemoteIdFromStatus - nextLastSyncedId) : 0

        return PhotoSyncSummary(
            downloaded: downloaded,
            skippedOlder: skippedBeforeWindow + skippedOlder,
            remainingNew: max(remainingNew, remainingNewFromStatus),
            failed: failed
        )
    }

    private func syncNewVideos() async throws -> Int {
        let cameraStatus: CameraStatus? = try? await getJSON(path: "/status.json")
        let latestRemoteVideoId = cameraStatus?.latest_video_id ?? 0

        var requestSince = lastSyncedVideoId
        if latestRemoteVideoId > 0 {
            let pendingRemoteVideoCount = latestRemoteVideoId - lastSyncedVideoId
            if pendingRemoteVideoCount > maxVideosPerSync {
                requestSince = max(lastSyncedVideoId, latestRemoteVideoId - maxVideosPerSync)
            }
        }

        let remoteVideos: [CreatorVideo] = try await getJSON(path: "/videos.json?since=\(requestSince)&limit=\(maxVideosPerSync)")
        let sorted = remoteVideos.sorted { $0.id < $1.id }

        var downloaded = 0
        var nextLastSyncedVideoId = max(lastSyncedVideoId, requestSince)

        var updatedVideosByID = Dictionary(uniqueKeysWithValues: videos.map { ($0.id, $0) })
        var updatedLocalVideoFiles = localVideoFiles

        for video in sorted {
            if hiddenVideoIDs.contains(video.id) {
                nextLastSyncedVideoId = max(nextLastSyncedVideoId, video.id)
                continue
            }

            let rawURL = rawVideoURL(for: video)
            let mp4URL = mp4VideoURL(for: video)

            let rawExists = await fileExists(at: rawURL)
            let mp4Exists = await fileExists(at: mp4URL)

            if !rawExists && !mp4Exists {
                syncProgressText = "Downloading video #\(video.id)..."
                let data = try await getRawData(path: video.url)
                try await writeData(data, to: rawURL)
                downloaded += 1
            }

            if !mp4Exists {
                let sourceForConversion = await fileExists(at: rawURL) ? rawURL : nil

                if let sourceForConversion {
                    syncProgressText = "Converting video #\(video.id) to MP4..."
                    isConvertingVideo = true
                    defer { isConvertingVideo = false }

                    do {
                        try await convertMJPEGVideoToMP4(sourceURL: sourceForConversion, outputURL: mp4URL)
                        updatedLocalVideoFiles[video.id] = mp4URL
                    } catch {
                        // If conversion fails, keep the raw .mjpg so the user can still share the file.
                        updatedLocalVideoFiles[video.id] = sourceForConversion
                        print("MP4 conversion failed for video \(video.id):", error)
                    }
                }
            } else {
                updatedLocalVideoFiles[video.id] = mp4URL
            }

            if updatedLocalVideoFiles[video.id] == nil {
                if await fileExists(at: mp4URL) {
                    updatedLocalVideoFiles[video.id] = mp4URL
                } else if await fileExists(at: rawURL) {
                    updatedLocalVideoFiles[video.id] = rawURL
                }
            }

            updatedVideosByID[video.id] = video
            nextLastSyncedVideoId = max(nextLastSyncedVideoId, video.id)
        }

        let visibleVideos = updatedVideosByID.values
            .filter { !hiddenVideoIDs.contains($0.id) }
            .sorted { $0.id > $1.id }

        videos = visibleVideos
        localVideoFiles = updatedLocalVideoFiles
        lastSyncedVideoId = nextLastSyncedVideoId

        saveVideoIndex()

        return downloaded
    }

    private func convertMJPEGVideoToMP4(sourceURL: URL, outputURL: URL) async throws {
        try await Task.detached(priority: .utility) {
            try CreatorVideoMP4Converter.convertMJPEGToMP4(
                sourceURL: sourceURL,
                outputURL: outputURL,
                frameDurationMs: 300
            )
        }.value
    }

    // MARK: - Network Helpers

    private func getJSON<T: Decodable>(path: String) async throws -> T {
        do {
            let data = try await getRawData(path: path)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            throw NSError(
                domain: "CreatorCamJSON",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "\(path) replied, but the JSON format did not match the app.",
                    NSUnderlyingErrorKey: decodingError
                ]
            )
        }
    }

    private func getRawData(path: String) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw URLError(.badURL)
        }

        let timeout = timeoutInterval(for: path)
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let maxAttempts = retryCount(for: path)
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                guard (200...299).contains(http.statusCode) else {
                    let snippet = String(data: data.prefix(160), encoding: .utf8) ?? ""
                    throw NSError(
                        domain: "CreatorCamHTTP",
                        code: http.statusCode,
                        userInfo: [
                            NSLocalizedDescriptionKey: "\(path) returned HTTP \(http.statusCode)\(snippet.isEmpty ? "" : ": \(snippet)")"
                        ]
                    )
                }

                return data
            } catch {
                lastError = error

                guard attempt < maxAttempts && isRetryableNetworkError(error) else {
                    throw networkError(error, path: path, timeout: timeout, attempt: attempt, maxAttempts: maxAttempts)
                }

                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }

        throw networkError(lastError ?? URLError(.unknown), path: path, timeout: timeout, attempt: maxAttempts, maxAttempts: maxAttempts)
    }

    private func timeoutInterval(for path: String) -> TimeInterval {
        if path.contains(".json") {
            return 20
        }

        if path.hasPrefix("/video?id=") {
            return 180
        }

        if path.hasPrefix("/photo?id=") || path == "/latest" {
            return 45
        }

        return 15
    }

    private func retryCount(for path: String) -> Int {
        if path.hasPrefix("/photo?id=") || path.hasPrefix("/video?id=") {
            return 2
        }

        return 1
    }

    private func isRetryableNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            return false
        }

        switch urlError.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost:
            return true
        default:
            return false
        }
    }

    private func networkError(_ error: Error, path: String, timeout: TimeInterval, attempt: Int, maxAttempts: Int) -> Error {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return NSError(
                    domain: "CreatorCamNetwork",
                    code: urlError.errorCode,
                    userInfo: [
                        NSLocalizedDescriptionKey: "\(path) timed out after \(Int(timeout))s\(maxAttempts > 1 ? " on attempt \(attempt)/\(maxAttempts)" : "")."
                    ]
                )
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                return NSError(
                    domain: "CreatorCamNetwork",
                    code: urlError.errorCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "\(path) could not reach the camera."
                ]
            )
            default:
                break
            }
        }

        return error
    }

    private func friendlySyncError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "The camera timed out. Stay on PocketCam Wi-Fi and try again."
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                return "Cannot reach the camera. Connect iPhone to the camera network, then try again."
            default:
                return urlError.localizedDescription
            }
        }

        let message = (error as NSError).localizedDescription
        if message.contains("/photos.json") || message.contains("/photo?id=") {
            return message
        }

        return "\(message) Confirm iPhone is connected to the camera network, then try again."
    }

    // MARK: - Background File Helpers

    private func fileExists(at url: URL) async -> Bool {
        await Task.detached(priority: .utility) {
            FileManager.default.fileExists(atPath: url.path)
        }.value
    }

    private func writeData(_ data: Data, to url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try data.write(to: url, options: [.atomic])
        }.value
    }

    private func removeItem(at url: URL) async {
        await Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: url)
        }.value
    }

    // MARK: - Local Photo Gallery

    private func createPhotosFolderIfNeeded() {
        do {
            try FileManager.default.createDirectory(
                at: photosFolderURL,
                withIntermediateDirectories: true
            )
        } catch {
            print("create photos folder error:", error)
        }
    }
    
    private func createEnhancedPhotosFolderIfNeeded() {
        do {
            try FileManager.default.createDirectory(
                at: enhancedPhotosFolderURL,
                withIntermediateDirectories: true
            )
        } catch {
            print("create enhanced photos folder error:", error)
        }
    }

    private func legacyCoreImagePhotoURL(for photo: CreatorPhoto) -> URL {
        let baseName = photo.filename.replacingOccurrences(of: ".jpg", with: "")
        return enhancedPhotosFolderURL.appendingPathComponent("\(baseName)_enhanced_v3.jpg")
    }

    private func enhancedPhotoURL(for photo: CreatorPhoto) -> URL {
        processedPhotoURL(for: photo, look: .enhance, enhanceFirst: false)
    }

    private func processedPhotoURL(
        for photo: CreatorPhoto,
        look: CreatorPhotoLook,
        enhanceFirst: Bool
    ) -> URL {
        let baseName = photo.filename.replacingOccurrences(of: ".jpg", with: "")
        return enhancedPhotosFolderURL.appendingPathComponent("\(baseName)_\(look.fileSuffix(enhanceFirst: enhanceFirst)).jpg")
    }

    private func adjustedPhotoURL(for photo: CreatorPhoto) -> URL {
        let baseName = photo.filename.replacingOccurrences(of: ".jpg", with: "")
        return enhancedPhotosFolderURL.appendingPathComponent("\(baseName)_manual_edit_v1.jpg")
    }

    private func aiEnhancedPhotoURL(for photo: CreatorPhoto) -> URL {
        let baseName = photo.filename.replacingOccurrences(of: ".jpg", with: "")
        return enhancedPhotosFolderURL.appendingPathComponent("\(baseName)_ai_v1.jpg")
    }

    private func processedPhotoURLs(for photo: CreatorPhoto) -> [URL] {
        CreatorPhotoLook.allCases.flatMap { look in
            let plainURL = processedPhotoURL(for: photo, look: look, enhanceFirst: false)
            guard look != .enhance else {
                return [plainURL]
            }

            return [
                plainURL,
                processedPhotoURL(for: photo, look: look, enhanceFirst: true)
            ]
        } + [
            adjustedPhotoURL(for: photo),
            legacyCoreImagePhotoURL(for: photo),
            aiEnhancedPhotoURL(for: photo)
        ]
    }

    private func mostRecentExistingProcessedPhotoURL(for photo: CreatorPhoto) -> URL? {
        processedPhotoURLs(for: photo)
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .max { lhs, rhs in
                modificationDate(for: lhs) < modificationDate(for: rhs)
            }
    }

    private func modificationDate(for url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func saveGalleryIndex() {
        do {
            let visiblePhotos = photos
                .filter { !hiddenPhotoIDs.contains($0.id) }
                .sorted { $0.id < $1.id }

            let data = try JSONEncoder().encode(visiblePhotos)
            UserDefaults.standard.set(data, forKey: galleryIndexKey)
        } catch {
            print("save gallery index error:", error)
        }
    }

    private func loadGalleryIndex() {
        guard let data = UserDefaults.standard.data(forKey: galleryIndexKey) else {
            photos = []
            return
        }

        do {
            photos = try JSONDecoder().decode([CreatorPhoto].self, from: data)
                .filter { !hiddenPhotoIDs.contains($0.id) }
                .sorted { $0.id > $1.id }
        } catch {
            print("load gallery index error:", error)
            photos = []
        }
    }

    private func loadLocalFiles() {
        var files: [Int: URL] = [:]

        for photo in photos {
            let originalURL = photosFolderURL.appendingPathComponent(photo.filename)

            if let processedURL = mostRecentExistingProcessedPhotoURL(for: photo) {
                files[photo.id] = processedURL
            } else if FileManager.default.fileExists(atPath: originalURL.path) {
                files[photo.id] = originalURL
            }
        }

        localFiles = files
    }

    private func loadHiddenPhotoIDs() {
        if let array = UserDefaults.standard.array(forKey: hiddenPhotoIDsKey) as? [Int] {
            hiddenPhotoIDs = Set(array)
        }
    }

    private func saveHiddenPhotoIDs() {
        UserDefaults.standard.set(Array(hiddenPhotoIDs), forKey: hiddenPhotoIDsKey)
    }

    func deletePhotosLocally(_ photosToDelete: [CreatorPhoto]) async {
        guard !photosToDelete.isEmpty else { return }

        var updatedLocalFiles = localFiles
        var updatedHiddenIDs = hiddenPhotoIDs

        for photo in photosToDelete {
            if let localURL = updatedLocalFiles[photo.id] {
                await removeItem(at: localURL)
            }

            let originalURL = photosFolderURL.appendingPathComponent(photo.filename)

            await removeItem(at: originalURL)
            for processedURL in processedPhotoURLs(for: photo) {
                await removeItem(at: processedURL)
            }

            updatedLocalFiles.removeValue(forKey: photo.id)
            updatedHiddenIDs.insert(photo.id)
        }

        let idsToDelete = Set(photosToDelete.map(\.id))

        localFiles = updatedLocalFiles
        hiddenPhotoIDs = updatedHiddenIDs
        photos.removeAll { idsToDelete.contains($0.id) }

        saveHiddenPhotoIDs()
        saveGalleryIndex()

        successMessage = "Deleted \(photosToDelete.count) photo\(photosToDelete.count == 1 ? "" : "s") from app gallery ✅"
        errorMessage = nil

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func enhancePhotos(_ targetPhotos: [CreatorPhoto]) async {
        await applyLook(.enhance, to: targetPhotos, enhanceFirst: false)
    }

    func enhanceCurrentPhoto(_ photo: CreatorPhoto) async {
        guard !isEnhancingLibrary else { return }

        guard CreatorOnDeviceAIEnhancer.isModelAvailable() else {
            errorMessage = "Add the RealESRGAN model to the Xcode project first."
            return
        }

        let originalURL = photosFolderURL.appendingPathComponent(photo.filename)
        let sourceURL: URL?

        if let currentURL = localFiles[photo.id] {
            sourceURL = currentURL
        } else if FileManager.default.fileExists(atPath: originalURL.path) {
            sourceURL = originalURL
        } else {
            sourceURL = nil
        }

        guard let sourceURL else {
            errorMessage = "Photo is not downloaded yet. Sync again first."
            return
        }

        let sourceBaseName = sourceURL.deletingPathExtension().lastPathComponent
        if sourceBaseName.contains("_enhance_v") || sourceBaseName.contains("_ai_look_") {
            successMessage = "This photo is already enhanced ✅"
            errorMessage = nil
            return
        }

        let outputURL: URL
        if let currentLook = plainLookForCurrentPhoto(photo) {
            outputURL = processedPhotoURL(for: photo, look: currentLook, enhanceFirst: true)
        } else {
            outputURL = enhancedPhotoURL(for: photo)
        }

        isEnhancingLibrary = true
        errorMessage = nil
        successMessage = nil
        syncProgressText = "Enhancing current photo..."
        defer {
            isEnhancingLibrary = false
            syncProgressText = nil
        }

        do {
            let enhancedData = try await Task.detached(priority: .userInitiated) { () throws -> Data in
                let data = try Data(contentsOf: sourceURL)
                return try CreatorOnDeviceAIEnhancer.enhanceJPEGData(data)
            }.value

            try await writeData(enhancedData, to: outputURL)
            localFiles[photo.id] = outputURL
            LocalImageMemoryCache.shared.removeAll()
            imageRefreshID += 1
            successMessage = "Enhanced current photo ✅"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            print("enhance current photo error:", error)
        }
    }

    private func plainLookForCurrentPhoto(_ photo: CreatorPhoto) -> CreatorPhotoLook? {
        guard let currentURL = localFiles[photo.id] else {
            return nil
        }

        let name = currentURL.deletingPathExtension().lastPathComponent

        for look in CreatorPhotoLook.filterCases {
            if name.hasSuffix("_look_\(look.rawValue)_v1") {
                return look
            }
        }

        return nil
    }

    func applyLook(_ look: CreatorPhotoLook, to targetPhotos: [CreatorPhoto]) async {
        await applyLook(look, to: targetPhotos, enhanceFirst: false)
    }

    func applyLook(
        _ look: CreatorPhotoLook,
        to targetPhotos: [CreatorPhoto],
        enhanceFirst: Bool
    ) async {
        guard !isEnhancingLibrary else { return }
        guard !targetPhotos.isEmpty else {
            errorMessage = "Select at least one photo."
            return
        }

        let shouldEnhanceFirst = enhanceFirst && look != .enhance
        let title = shouldEnhanceFirst ? "Enhanced \(look.title)" : look.title

        guard !look.requiresModel(enhanceFirst: shouldEnhanceFirst) || CreatorOnDeviceAIEnhancer.isModelAvailable() else {
            errorMessage = "Add the RealESRGAN model to the Xcode project first."
            return
        }

        isEnhancingLibrary = true
        errorMessage = nil
        successMessage = nil
        defer {
            isEnhancingLibrary = false
            syncProgressText = nil
        }

        var updatedLocalFiles = localFiles
        var rebuilt = 0
        var lastError: Error?

        for (index, photo) in targetPhotos.enumerated() {
            syncProgressText = "\(title) \(index + 1) of \(targetPhotos.count)..."

            let originalURL = photosFolderURL.appendingPathComponent(photo.filename)
            let sourceURL = FileManager.default.fileExists(atPath: originalURL.path) ? originalURL : localFiles[photo.id]

            guard let sourceURL else {
                continue
            }

            let outputURL = processedPhotoURL(for: photo, look: look, enhanceFirst: shouldEnhanceFirst)

            do {
                let enhancedData = try await Task.detached(priority: .userInitiated) { () throws -> Data in
                    let data = try Data(contentsOf: sourceURL)
                    return try CreatorOnDeviceAIEnhancer.processJPEGData(data, look: look, enhanceFirst: shouldEnhanceFirst)
                }.value

                try await writeData(enhancedData, to: outputURL)
                updatedLocalFiles[photo.id] = outputURL
                rebuilt += 1
            } catch {
                lastError = error
                print("on-device enhance error:", error)
            }
        }

        localFiles = updatedLocalFiles
        LocalImageMemoryCache.shared.removeAll()
        imageRefreshID += 1

        if rebuilt > 0 {
            successMessage = "\(title) applied to \(rebuilt) photo\(rebuilt == 1 ? "" : "s") ✅"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else if let lastError {
            errorMessage = lastError.localizedDescription
        } else {
            errorMessage = "Could not apply \(title)."
        }
    }

    @discardableResult
    func applyAdjustments(_ adjustments: CreatorPhotoAdjustments, to photo: CreatorPhoto) async -> Bool {
        guard !isEnhancingLibrary else { return false }
        guard !adjustments.isNeutral else {
            successMessage = "Edits are already neutral ✅"
            errorMessage = nil
            return false
        }

        let originalURL = photosFolderURL.appendingPathComponent(photo.filename)
        let sourceURL: URL?

        if let currentURL = localFiles[photo.id] {
            sourceURL = currentURL
        } else if FileManager.default.fileExists(atPath: originalURL.path) {
            sourceURL = originalURL
        } else {
            sourceURL = nil
        }

        guard let sourceURL else {
            errorMessage = "Photo is not downloaded yet. Sync again first."
            return false
        }

        let outputURL = adjustedPhotoURL(for: photo)

        isEnhancingLibrary = true
        errorMessage = nil
        successMessage = nil
        syncProgressText = "Applying edits..."
        defer {
            isEnhancingLibrary = false
            syncProgressText = nil
        }

        do {
            let editedData = try await Task.detached(priority: .userInitiated) { () throws -> Data in
                let data = try Data(contentsOf: sourceURL)
                return try CreatorOnDeviceAIEnhancer.adjustJPEGData(data, adjustments: adjustments)
            }.value

            try await writeData(editedData, to: outputURL)
            localFiles[photo.id] = outputURL
            LocalImageMemoryCache.shared.removeAll()
            imageRefreshID += 1
            successMessage = "Edits applied ✅"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("manual edit error:", error)
            return false
        }
    }

    func restoreOriginalPhoto(_ photo: CreatorPhoto) async {
        let originalURL = photosFolderURL.appendingPathComponent(photo.filename)

        guard await fileExists(at: originalURL) else {
            errorMessage = "Original photo is not downloaded anymore. Sync again to restore it."
            return
        }

        for processedURL in processedPhotoURLs(for: photo) {
            await removeItem(at: processedURL)
        }

        localFiles[photo.id] = originalURL
        LocalImageMemoryCache.shared.removeAll()
        imageRefreshID += 1
        successMessage = "Back to original photo ✅"
        errorMessage = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func isShowingEnhancedPhoto(_ photo: CreatorPhoto) -> Bool {
        guard let url = localFiles[photo.id] else {
            return false
        }

        return url.deletingLastPathComponent().standardizedFileURL == enhancedPhotosFolderURL.standardizedFileURL
    }

    // MARK: - Local Video Gallery

    private func createVideosFolderIfNeeded() {
        do {
            try FileManager.default.createDirectory(
                at: videosFolderURL,
                withIntermediateDirectories: true
            )
        } catch {
            print("create videos folder error:", error)
        }
    }

    private func saveVideoIndex() {
        do {
            let visibleVideos = videos
                .filter { !hiddenVideoIDs.contains($0.id) }
                .sorted { $0.id < $1.id }

            let data = try JSONEncoder().encode(visibleVideos)
            UserDefaults.standard.set(data, forKey: videoIndexKey)
        } catch {
            print("save video index error:", error)
        }
    }

    private func loadVideoIndex() {
        guard let data = UserDefaults.standard.data(forKey: videoIndexKey) else {
            videos = []
            return
        }

        do {
            videos = try JSONDecoder().decode([CreatorVideo].self, from: data)
                .filter { !hiddenVideoIDs.contains($0.id) }
                .sorted { $0.id > $1.id }
        } catch {
            print("load video index error:", error)
            videos = []
        }
    }

    private func loadLocalVideoFiles() {
        var files: [Int: URL] = [:]

        for video in videos {
            let mp4URL = mp4VideoURL(for: video)
            let rawURL = rawVideoURL(for: video)

            if FileManager.default.fileExists(atPath: mp4URL.path) {
                files[video.id] = mp4URL
            } else if FileManager.default.fileExists(atPath: rawURL.path) {
                files[video.id] = rawURL
            }
        }

        localVideoFiles = files
    }

    private func loadHiddenVideoIDs() {
        if let array = UserDefaults.standard.array(forKey: hiddenVideoIDsKey) as? [Int] {
            hiddenVideoIDs = Set(array)
        }
    }

    private func saveHiddenVideoIDs() {
        UserDefaults.standard.set(Array(hiddenVideoIDs), forKey: hiddenVideoIDsKey)
    }

    func deleteVideosLocally(_ videosToDelete: [CreatorVideo]) async {
        guard !videosToDelete.isEmpty else { return }

        var updatedLocalVideoFiles = localVideoFiles
        var updatedHiddenIDs = hiddenVideoIDs

        for video in videosToDelete {
            if let localURL = updatedLocalVideoFiles[video.id] {
                await removeItem(at: localURL)
            }

            await removeItem(at: rawVideoURL(for: video))
            await removeItem(at: mp4VideoURL(for: video))

            updatedLocalVideoFiles.removeValue(forKey: video.id)
            updatedHiddenIDs.insert(video.id)
        }

        let idsToDelete = Set(videosToDelete.map(\.id))

        localVideoFiles = updatedLocalVideoFiles
        hiddenVideoIDs = updatedHiddenIDs
        videos.removeAll { idsToDelete.contains($0.id) }

        saveHiddenVideoIDs()
        saveVideoIndex()

        successMessage = "Deleted \(videosToDelete.count) video\(videosToDelete.count == 1 ? "" : "s") from app gallery ✅"
        errorMessage = nil

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Reset

    func resetLocalGallery() async {
        await removeItem(at: photosFolderURL)
        await removeItem(at: enhancedPhotosFolderURL)
        await removeItem(at: videosFolderURL)

        UserDefaults.standard.removeObject(forKey: lastSyncedIdKey)
        UserDefaults.standard.removeObject(forKey: lastSyncedVideoIdKey)
        UserDefaults.standard.removeObject(forKey: galleryIndexKey)
        UserDefaults.standard.removeObject(forKey: videoIndexKey)
        UserDefaults.standard.removeObject(forKey: hiddenPhotoIDsKey)
        UserDefaults.standard.removeObject(forKey: hiddenVideoIDsKey)

        createPhotosFolderIfNeeded()
        createEnhancedPhotosFolderIfNeeded()
        createVideosFolderIfNeeded()

        photos = []
        videos = []
        localFiles = [:]
        localVideoFiles = [:]
        hiddenPhotoIDs = []
        hiddenVideoIDs = []
        errorMessage = nil
        successMessage = nil
        syncProgressText = nil
        connectionState = .idle

        LocalImageMemoryCache.shared.removeAll()
    }

    // MARK: - Save to iPhone Photos

    func saveToPhotos(_ photo: CreatorPhoto) async {
        guard let url = localFiles[photo.id] else {
            errorMessage = "Photo is not downloaded yet."
            return
        }

        guard !isSavingToPhotos else { return }

        isSavingToPhotos = true
        errorMessage = nil
        successMessage = nil
        defer { isSavingToPhotos = false }

        let status = await requestPhotoAddPermission()

        guard status == .authorized || status == .limited else {
            errorMessage = "Allow Photos access to save images."
            return
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                } completionHandler: { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "CreatorCam",
                                code: 20,
                                userInfo: [NSLocalizedDescriptionKey: "Could not save to Photos."]
                            )
                        )
                    }
                }
            }

            successMessage = "Saved to Photos ✅"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Could not save to Photos."
            print("save to photos error:", error)
        }
    }

    func saveVideoToPhotos(_ video: CreatorVideo) async {
        guard let url = localVideoFiles[video.id] else {
            errorMessage = "Video is not downloaded yet."
            return
        }

        guard url.pathExtension.lowercased() == "mp4" else {
            errorMessage = "Video is still MJPG. Sync again to convert it to MP4."
            return
        }

        guard !isSavingVideoToPhotos else { return }

        isSavingVideoToPhotos = true
        errorMessage = nil
        successMessage = nil
        defer { isSavingVideoToPhotos = false }

        let status = await requestPhotoAddPermission()

        guard status == .authorized || status == .limited else {
            errorMessage = "Allow Photos access to save videos."
            return
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } completionHandler: { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "CreatorCam",
                                code: 21,
                                userInfo: [NSLocalizedDescriptionKey: "Could not save video to Photos."]
                            )
                        )
                    }
                }
            }

            successMessage = "Saved video to Photos ✅"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Could not save video to Photos."
            print("save video to photos error:", error)
        }
    }

    private func requestPhotoAddPermission() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
