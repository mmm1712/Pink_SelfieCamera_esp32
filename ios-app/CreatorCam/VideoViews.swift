import SwiftUI
import UIKit
import AVKit
import AVFoundation
import ImageIO

struct MP4VideoPlayerCard: View {
    let url: URL

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CreatorTheme.ink.opacity(0.94),
                            CreatorTheme.rose.opacity(0.75),
                            CreatorTheme.hotPink.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let player {
                VideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                    }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Preparing video…")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .onAppear {
            if player == nil {
                player = AVPlayer(url: url)
            }
        }
        .onChange(of: url) { _, newURL in
            player?.pause()
            player = AVPlayer(url: newURL)
        }
    }
}

struct VideoDetailView: View {
    let video: CreatorVideo
    @ObservedObject var vm: CreatorCamViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CreatorTheme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                if let url = vm.localVideoFiles[video.id] {
                    VStack(spacing: 18) {
                        if url.pathExtension.lowercased() == "mp4" {
                            MP4VideoPlayerCard(url: url)
                                .frame(height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                                        .stroke(.white.opacity(0.18), lineWidth: 1)
                                }
                                .padding(.horizontal, 16)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                CreatorTheme.ink.opacity(0.94),
                                                CreatorTheme.rose.opacity(0.75),
                                                CreatorTheme.hotPink.opacity(0.55)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(height: 280)

                                VStack(spacing: 14) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 60, weight: .bold))

                                    Text("Video saved in app")
                                        .font(.title3.weight(.bold))

                                    Text(video.filename)
                                        .font(.footnote.monospaced())
                                        .opacity(0.85)

                                    Text(formatFileSize(video.size))
                                        .font(.caption.weight(.semibold))
                                        .opacity(0.75)
                                }
                                .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 16)
                        }

                        Text(url.pathExtension.lowercased() == "mp4" ? "Converted to MP4 on your iPhone after sync. You can share it or save it to Photos." : "This video is still MJPG. Sync again to convert it to MP4.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(CreatorTheme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        HStack(spacing: 12) {
                            ShareLink(item: url) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(CreatorButtonStyle())

                            Button {
                                Task {
                                    await vm.saveVideoToPhotos(video)
                                }
                            } label: {
                                if vm.isSavingVideoToPhotos {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Label("Save", systemImage: "square.and.arrow.down")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(CreatorButtonStyle())
                            .disabled(url.pathExtension.lowercased() != "mp4" || vm.isSavingVideoToPhotos)
                        }
                        .padding(.horizontal, 16)
                    }
                } else {
                    ContentUnavailableView(
                        "Video not downloaded",
                        systemImage: "video.badge.exclamationmark",
                        description: Text("Sync again to download this video.")
                    )
                }

                Spacer()
            }
            .padding(.top, 16)
        }
        .navigationTitle(video.filename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Settings


enum CreatorVideoMP4Converter {
    nonisolated static func convertMJPEGToMP4(sourceURL: URL, outputURL: URL, frameDurationMs: Int64) throws {
        let data = try Data(contentsOf: sourceURL)
        let frames = extractJPEGFrames(from: data)

        guard !frames.isEmpty else {
            throw NSError(
                domain: "CreatorCamVideo",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No JPEG frames found in MJPG file."]
            )
        }

        guard let firstImage = UIImage(data: frames[0]), let firstCG = firstImage.cgImage else {
            throw NSError(
                domain: "CreatorCamVideo",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not decode first video frame."]
            )
        }

        let width = max(2, firstCG.width - (firstCG.width % 2))
        let height = max(2, firstCG.height - (firstCG.height % 2))

        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(350_000, width * height * 3),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
        )

        guard writer.canAdd(input) else {
            throw NSError(
                domain: "CreatorCamVideo",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not add video input to writer."]
            )
        }

        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? NSError(
                domain: "CreatorCamVideo",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Could not start MP4 writer."]
            )
        }

        writer.startSession(atSourceTime: .zero)

        for (index, frameData) in frames.enumerated() {
            autoreleasepool {
                guard let image = UIImage(data: frameData) else { return }

                while !input.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.005)
                }

                do {
                    let pixelBuffer = try makePixelBuffer(from: image, width: width, height: height)
                    let time = CMTime(value: Int64(index) * frameDurationMs, timescale: 1000)
                    adaptor.append(pixelBuffer, withPresentationTime: time)
                } catch {
                    print("Could not append video frame \(index):", error)
                }
            }
        }

        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        if writer.status == .failed {
            throw writer.error ?? NSError(
                domain: "CreatorCamVideo",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "MP4 writer failed."]
            )
        }
    }

    private nonisolated static func extractJPEGFrames(from data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var frames: [Data] = []
        var index = 0

        while index < bytes.count - 1 {
            guard bytes[index] == 0xFF && bytes[index + 1] == 0xD8 else {
                index += 1
                continue
            }

            let start = index
            index += 2

            while index < bytes.count - 1 {
                if bytes[index] == 0xFF && bytes[index + 1] == 0xD9 {
                    let end = index + 2
                    frames.append(data.subdata(in: start..<end))
                    index = end
                    break
                }

                index += 1
            }
        }

        return frames
    }

    private nonisolated static func makePixelBuffer(from image: UIImage, width: Int, height: Int) throws -> CVPixelBuffer {
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw NSError(
                domain: "CreatorCamVideo",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Could not create pixel buffer."]
            )
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw NSError(
                domain: "CreatorCamVideo",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap context."]
            )
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .medium

        guard let cgImage = image.cgImage else {
            throw NSError(
                domain: "CreatorCamVideo",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "Could not read CGImage from frame."]
            )
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}

// MARK: - Helpers

func formatFileSize(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
}

// MARK: - Theme

