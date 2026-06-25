import SwiftUI
import UIKit

struct PhotoDetailView: View {
    let photo: CreatorPhoto
    @ObservedObject var vm: CreatorCamViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var adjustments = CreatorPhotoAdjustments.neutral

    var body: some View {
        ZStack {
            CreatorTheme.background.ignoresSafeArea()

            if let url = vm.localFiles[photo.id] {
                VStack(spacing: 12) {
                    EditablePhotoPreview(localURL: url, adjustments: adjustments, reloadToken: vm.imageRefreshID)
                        .frame(height: 278)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CreatorButtonStyle())

                        Button {
                            Task {
                                await vm.saveToPhotos(photo)
                            }
                        } label: {
                            if vm.isSavingToPhotos {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Save", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(CreatorButtonStyle())
                    }
                    .padding(.horizontal, 16)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            enhancePanel
                            lookStrip
                            adjustmentPanel

                            if vm.isShowingEnhancedPhoto(photo) {
                                Button {
                                    Task {
                                        await vm.restoreOriginalPhoto(photo)
                                    }
                                } label: {
                                    Label("Back to Original", systemImage: "arrow.uturn.backward")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SecondaryCreatorButtonStyle())
                                .disabled(vm.isEnhancingLibrary)
                                .padding(.horizontal, 16)
                            }

                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("Delete from App Gallery", systemImage: "trash.fill")
                                    .font(.headline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundStyle(.white)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.red.opacity(0.86))
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 28)
                    }
                }
                .padding(.top, 12)
            } else {
                ContentUnavailableView(
                    "Photo not downloaded",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("Sync again to download this photo.")
                )
            }
        }
        .navigationTitle(photo.filename)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete this photo?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await vm.deletePhotosLocally([photo])
                    dismiss()
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the photo only from the app gallery. The original file stays on the PocketCam SD card.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
    }

    private var enhancePanel: some View {
        Button {
            Task {
                if adjustments.isNeutral {
                    await vm.enhanceCurrentPhoto(photo)
                } else {
                    let saved = await vm.applyAdjustments(adjustments, to: photo)
                    if saved {
                        adjustments = .neutral
                        await vm.enhanceCurrentPhoto(photo)
                    }
                }
            }
        } label: {
            if vm.isEnhancingLibrary {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Label(
                    CreatorOnDeviceAIEnhancer.isModelAvailable() ? "Enhance" : "Add AI Model",
                    systemImage: "wand.and.stars"
                )
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(SecondaryCreatorButtonStyle())
        .disabled(!CreatorOnDeviceAIEnhancer.isModelAvailable() || vm.isEnhancingLibrary)
        .padding(.horizontal, 16)
    }

    private var lookStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Looks")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CreatorTheme.ink)

                Spacer()

                if vm.isEnhancingLibrary {
                    ProgressView()
                        .tint(CreatorTheme.hotPink)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await vm.restoreOriginalPhoto(photo)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 18, weight: .bold))

                            Text("Original")
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .foregroundStyle(CreatorTheme.ink)
                        .frame(width: 86, height: 76)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CreatorTheme.warmCream.opacity(0.9))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.78), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isEnhancingLibrary)

                    ForEach(CreatorPhotoLook.filterCases) { look in
                        Button {
                            Task {
                                await vm.applyLook(look, to: [photo], enhanceFirst: false)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: look.systemImage)
                                    .font(.system(size: 18, weight: .bold))

                                Text(look.title)
                                    .font(.caption.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .foregroundStyle(CreatorTheme.ink)
                            .frame(width: 86, height: 76)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(CreatorTheme.warmCream.opacity(0.9))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(.white.opacity(0.78), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isEnhancingLibrary)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var adjustmentPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Adjust", systemImage: "slider.horizontal.3")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CreatorTheme.ink)

                Spacer()

                Button("Reset") {
                    adjustments = .neutral
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(CreatorTheme.hotPink)
                .disabled(vm.isEnhancingLibrary)
            }

            VStack(spacing: 12) {
                adjustmentSlider("Exposure", value: $adjustments.exposure, range: -1.0...1.0, step: 0.05)
                adjustmentSlider("Brightness", value: $adjustments.brightness, range: -0.25...0.25, step: 0.01)
                adjustmentSlider("Contrast", value: $adjustments.contrast, range: 0.65...1.45, step: 0.01, neutral: 1.0)
                adjustmentSlider("Saturation", value: $adjustments.saturation, range: 0.0...1.8, step: 0.01, neutral: 1.0)
                adjustmentSlider("Warmth", value: $adjustments.warmth, range: -1.0...1.0, step: 0.02)
                adjustmentSlider("Highlights", value: $adjustments.highlights, range: -1.0...1.0, step: 0.02)
                adjustmentSlider("Shadows", value: $adjustments.shadows, range: -1.0...1.0, step: 0.02)
                adjustmentSlider("Sharpen", value: $adjustments.sharpen, range: 0.0...1.0, step: 0.02)
                adjustmentSlider("Grain", value: $adjustments.grain, range: 0.0...1.0, step: 0.02)
                adjustmentSlider("Vignette", value: $adjustments.vignette, range: 0.0...1.0, step: 0.02)
            }

            Button {
                Task {
                    let saved = await vm.applyAdjustments(adjustments, to: photo)
                    if saved {
                        adjustments = .neutral
                    }
                }
            } label: {
                if vm.isEnhancingLibrary {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Save Edits", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(SecondaryCreatorButtonStyle())
            .disabled(vm.isEnhancingLibrary || adjustments.isNeutral)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CreatorTheme.card.opacity(0.82))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.78), lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    private func adjustmentSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        neutral: Double = 0.0
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CreatorTheme.ink)

                Spacer()

                Text(adjustmentValueText(value.wrappedValue - neutral))
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(CreatorTheme.muted)
            }

            Slider(value: value, in: range, step: step)
                .tint(CreatorTheme.hotPink)
        }
    }

    private func adjustmentValueText(_ value: Double) -> String {
        if abs(value) < 0.005 {
            return "0"
        }

        if value > 0 {
            return String(format: "+%.2f", value)
        }

        return String(format: "%.2f", value)
    }
}



final class LocalImageMemoryCache {
    static let shared = LocalImageMemoryCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 220
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

// MARK: - Local Image View

struct EditablePhotoPreview: View {
    let localURL: URL
    let adjustments: CreatorPhotoAdjustments
    var reloadToken: Int = 0

    @State private var baseImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var currentPath: String?
    @State private var renderTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let image = previewImage ?? baseImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            CreatorTheme.warmCream,
                            CreatorTheme.pinkMist,
                            CreatorTheme.card
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    ProgressView()
                        .tint(CreatorTheme.hotPink)
                }
            }
        }
        .onAppear(perform: loadBaseImage)
        .onChange(of: localURL) { _, _ in
            loadBaseImage()
        }
        .onChange(of: reloadToken) { _, _ in
            loadBaseImage()
        }
        .onChange(of: adjustments) { _, _ in
            schedulePreviewRender()
        }
        .onDisappear {
            renderTask?.cancel()
        }
    }

    private func loadBaseImage() {
        renderTask?.cancel()
        baseImage = nil
        previewImage = nil

        let path = localURL.path
        currentPath = path

        Task.detached(priority: .utility) {
            let loaded = Self.loadImage(at: path, maxPixelSize: 1800)

            await MainActor.run {
                guard currentPath == path else { return }
                baseImage = loaded
                previewImage = loaded
                schedulePreviewRender()
            }
        }
    }

    private func schedulePreviewRender() {
        guard let baseImage else {
            previewImage = nil
            return
        }

        renderTask?.cancel()

        if adjustments.isNeutral {
            previewImage = baseImage
            return
        }

        let sourceImage = baseImage
        let requestedAdjustments = adjustments

        renderTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }

            let rendered = await Task.detached(priority: .userInitiated) {
                CreatorOnDeviceAIEnhancer.previewImage(sourceImage, adjustments: requestedAdjustments) ?? sourceImage
            }.value

            guard !Task.isCancelled else { return }
            previewImage = rendered
        }
    }

    private nonisolated static func loadImage(at path: String, maxPixelSize: CGFloat) -> UIImage? {
        autoreleasepool {
            let url = URL(fileURLWithPath: path) as CFURL

            guard let source = CGImageSourceCreateWithURL(url, [
                kCGImageSourceShouldCache: false
            ] as CFDictionary) else {
                return UIImage(contentsOfFile: path)
            }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return UIImage(contentsOfFile: path)
            }

            return UIImage(cgImage: cgImage)
        }
    }
}

struct LocalPhotoImage: View {
    let localURL: URL?
    var contentMode: ContentMode = .fill
    var maxPixelSize: CGFloat? = 520
    var reloadToken: Int = 0

    @State private var image: UIImage?
    @State private var currentPath: String?
    @State private var currentRequestKey: String?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            CreatorTheme.warmCream,
                            CreatorTheme.pinkMist,
                            CreatorTheme.card
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(CreatorTheme.muted.opacity(0.7))
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: localURL) { _, _ in
            load()
        }
        .onChange(of: reloadToken) { _, _ in
            load()
        }
    }

    private func load() {
        guard let localURL else {
            image = nil
            currentPath = nil
            currentRequestKey = nil
            return
        }

        let path = localURL.path
        let requestedMaxPixelSize = maxPixelSize
        let cacheKey = "\(path)#\(Int(requestedMaxPixelSize ?? 0))#\(reloadToken)"
        currentPath = path
        currentRequestKey = cacheKey

        if let cached = LocalImageMemoryCache.shared.image(forKey: cacheKey) {
            image = cached
            return
        }

        Task.detached(priority: .utility) {
            let loaded = Self.loadImage(at: path, maxPixelSize: requestedMaxPixelSize)

            await MainActor.run {
                guard currentPath == path, currentRequestKey == cacheKey else { return }

                if let loaded {
                    LocalImageMemoryCache.shared.setImage(loaded, forKey: cacheKey)
                    image = loaded
                }
            }
        }
    }

    private nonisolated static func loadImage(at path: String, maxPixelSize: CGFloat?) -> UIImage? {
        guard let maxPixelSize, maxPixelSize > 0 else {
            return UIImage(contentsOfFile: path)
        }

        return autoreleasepool {
            let url = URL(fileURLWithPath: path) as CFURL

            guard let source = CGImageSourceCreateWithURL(url, [
                kCGImageSourceShouldCache: false
            ] as CFDictionary) else {
                return UIImage(contentsOfFile: path)
            }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return UIImage(contentsOfFile: path)
            }

            return UIImage(cgImage: cgImage)
        }
    }
}

// MARK: - MJPG to MP4 Converter

