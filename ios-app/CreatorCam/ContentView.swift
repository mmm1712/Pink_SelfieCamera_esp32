import SwiftUI

// MARK: - Main View

struct ContentView: View {
    @StateObject private var vm = CreatorCamViewModel()

    @State private var selectedPhoto: CreatorPhoto?
    @State private var selectedVideo: CreatorVideo?

    @State private var galleryTab: GalleryTab = .photos

    @State private var isEditingGallery = false
    @State private var selectedPhotoIDs: Set<Int> = []
    @State private var selectedVideoIDs: Set<Int> = []

    @State private var showDeleteSelectedAlert = false
    @State private var showResetAlert = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                CreatorTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        heroCard

                        if let progress = vm.syncProgressText {
                            messageCard(progress, color: CreatorTheme.hotPink, icon: "arrow.triangle.2.circlepath")
                        }

                        if let success = vm.successMessage {
                            messageCard(success, color: .green, icon: "checkmark.circle.fill")
                        }

                        if let error = vm.errorMessage {
                            messageCard(error, color: .orange, icon: "exclamationmark.triangle.fill")
                        }

                        tabPicker
                        gallerySection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 9) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(CreatorTheme.hotPink)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("PocketCam")
                                .font(.headline.weight(.semibold))

                            Text("pocket camera")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            isEditingGallery.toggle()
                            selectedPhotoIDs = []
                            selectedVideoIDs = []
                        }
                    } label: {
                        Text(isEditingGallery ? "Done" : "Select")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isCurrentTabEmpty ? CreatorTheme.muted : CreatorTheme.ink)
                    }
                    .disabled(isCurrentTabEmpty || vm.isLoading)
                }
            }
            .sheet(item: $selectedPhoto) { photo in
                NavigationStack {
                    PhotoDetailView(photo: photo, vm: vm)
                }
            }
            .sheet(item: $selectedVideo) { video in
                NavigationStack {
                    VideoDetailView(video: video, vm: vm)
                }
            }
            .alert(deleteAlertTitle, isPresented: $showDeleteSelectedAlert) {
                Button(deleteAlertButtonTitle, role: .destructive) {
                    Task {
                        if galleryTab == .photos {
                            let photosToDelete = vm.photos.filter { selectedPhotoIDs.contains($0.id) }
                            await vm.deletePhotosLocally(photosToDelete)
                            selectedPhotoIDs = []
                        } else {
                            let videosToDelete = vm.videos.filter { selectedVideoIDs.contains($0.id) }
                            await vm.deleteVideosLocally(videosToDelete)
                            selectedVideoIDs = []
                        }

                        isEditingGallery = false
                    }
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes selected items only from the app gallery. Original files stay safe on the PocketCam SD card.")
            }
            .alert("Reset local gallery?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    Task {
                        await vm.resetLocalGallery()
                        selectedPhotoIDs = []
                        selectedVideoIDs = []
                        isEditingGallery = false
                    }
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This clears photos and videos from the app gallery on your iPhone. Original files stay on the PocketCam SD card.")
            }
            .task {
                await vm.checkConnection()
            }
            .refreshable {
                await vm.connectAndSync()
            }
        }
        .tint(CreatorTheme.hotPink)
    }

    private var isCurrentTabEmpty: Bool {
        switch galleryTab {
        case .photos:
            return vm.photos.isEmpty
        case .videos:
            return vm.videos.isEmpty
        }
    }

    private var selectedCountForCurrentTab: Int {
        switch galleryTab {
        case .photos:
            return selectedPhotoIDs.count
        case .videos:
            return selectedVideoIDs.count
        }
    }

    private var deleteAlertTitle: String {
        galleryTab == .photos ? "Delete selected photos?" : "Delete selected videos?"
    }

    private var deleteAlertButtonTitle: String {
        "Delete \(selectedCountForCurrentTab)"
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gallery")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(CreatorTheme.ink)

                    Text(vm.statusSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CreatorTheme.muted)
                }

                Spacer()

                Image("CameraBadge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: CreatorTheme.hotPink.opacity(0.18), radius: 10, x: 0, y: 5)
            }

            HStack(spacing: 10) {
                statCard(title: vm.savedCountText, subtitle: "photos")
                statCard(title: vm.videoCountText, subtitle: "videos")
                statCard(title: vm.pendingText, subtitle: "waiting")
            }

            statusPanel

            latestPhotoPreview

            Button {
                Task {
                    await vm.connectAndSync()
                }
            } label: {
                HStack(spacing: 10) {
                    if vm.isLoading || vm.isJoiningWiFi {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }

                    Text(buttonTitle)
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [CreatorTheme.hotPink, CreatorTheme.rose],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: CreatorTheme.hotPink.opacity(0.22), radius: 18, x: 0, y: 10)
            }
            .disabled(vm.isLoading || vm.isJoiningWiFi)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(CreatorTheme.card.opacity(0.86))
                .shadow(color: .black.opacity(0.08), radius: 22, x: 0, y: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        }
    }

    private var buttonTitle: String {
        if vm.isJoiningWiFi { return "Connecting" }
        if vm.isLoading { return "Syncing" }
        return "Sync"
    }

    @ViewBuilder
    private var latestPhotoPreview: some View {
        if let latest = vm.photos.first {
            Button {
                selectedPhoto = latest
            } label: {
                HStack(spacing: 12) {
                    LocalPhotoImage(localURL: vm.localFiles[latest.id], reloadToken: vm.imageRefreshID)
                        .frame(width: 74, height: 74)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latest photo")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(CreatorTheme.hotPink)

                        Text("#\(latest.id) · \(formatFileSize(latest.size))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CreatorTheme.ink)

                        Text("Tap to preview")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(CreatorTheme.muted)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        Task {
                            await vm.deletePhotosLocally([latest])
                        }
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.red.opacity(0.9))
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.86))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white.opacity(0.70))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.82), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var statusPanel: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(vm.connectionState.dotColor)
                .frame(width: 10, height: 10)

            Text(vm.connectionState.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CreatorTheme.ink)

            Spacer()

            Button {
                Task {
                    await vm.checkConnection()
                }
            } label: {
                Text("Check")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(CreatorTheme.hotPink)
            }
            .disabled(vm.isLoading)
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CreatorTheme.warmCream.opacity(0.8))
        )
    }

    private func statCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(CreatorTheme.ink)

            Text(subtitle.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(CreatorTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CreatorTheme.warmCream.opacity(0.80))
        )
    }

    private func messageCard(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CreatorTheme.ink)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CreatorTheme.card.opacity(0.9))
        )
    }

    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(GalleryTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        galleryTab = tab
                        selectedPhotoIDs = []
                        selectedVideoIDs = []
                        isEditingGallery = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab == .photos ? "photo.fill" : "video.fill")
                        Text(tab.rawValue)
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(galleryTab == tab ? .white : CreatorTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(galleryTab == tab ? CreatorTheme.hotPink : CreatorTheme.card.opacity(0.85))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            galleryHeader

            switch galleryTab {
            case .photos:
                photoGallery
            case .videos:
                videoGallery
            }
        }
    }

    private var galleryHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditingGallery ? "Select \(galleryTab.rawValue)" : galleryTab.rawValue)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(CreatorTheme.ink)

                Text(isEditingGallery ? "\(selectedCountForCurrentTab) selected" : galleryCountText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CreatorTheme.muted)
            }

            Spacer()

            if isEditingGallery {
                Button(selectAllTitle) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        toggleSelectAll()
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(CreatorTheme.hotPink)
            } else {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Text("Reset")
                        .font(.caption.weight(.bold))
                }
                .disabled(vm.photos.isEmpty && vm.videos.isEmpty || vm.isLoading)
            }
        }
    }

    private var galleryCountText: String {
        switch galleryTab {
        case .photos:
            return "\(vm.photos.count) total"
        case .videos:
            return "\(vm.videos.count) total"
        }
    }

    private var selectAllTitle: String {
        switch galleryTab {
        case .photos:
            return selectedPhotoIDs.count == vm.photos.count ? "Clear" : "Select All"
        case .videos:
            return selectedVideoIDs.count == vm.videos.count ? "Clear" : "Select All"
        }
    }

    private func toggleSelectAll() {
        switch galleryTab {
        case .photos:
            if selectedPhotoIDs.count == vm.photos.count {
                selectedPhotoIDs = []
            } else {
                selectedPhotoIDs = Set(vm.photos.map(\.id))
            }
        case .videos:
            if selectedVideoIDs.count == vm.videos.count {
                selectedVideoIDs = []
            } else {
                selectedVideoIDs = Set(vm.videos.map(\.id))
            }
        }
    }

    private var photoGallery: some View {
        Group {
            if vm.photos.isEmpty {
                emptyState(
                    icon: "photo.on.rectangle.angled",
                    title: "No photos yet",
                    text: "Take photos on PocketCam, connect to its Wi-Fi, then tap Sync."
                )
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(vm.photos) { photo in
                        Button {
                            if isEditingGallery {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                    if selectedPhotoIDs.contains(photo.id) {
                                        selectedPhotoIDs.remove(photo.id)
                                    } else {
                                        selectedPhotoIDs.insert(photo.id)
                                    }
                                }
                            } else {
                                selectedPhoto = photo
                            }
                        } label: {
                            photoGridCell(photo)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isEditingGallery {
                    deleteSelectedButton
                }
            }
        }
    }

    private var videoGallery: some View {
        Group {
            if vm.videos.isEmpty {
                emptyState(
                    icon: "video.slash",
                    title: "No videos yet",
                    text: "Record videos on PocketCam, then sync them into the app. They are saved as MJPG files for now."
                )
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(vm.videos) { video in
                        Button {
                            if isEditingGallery {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                    if selectedVideoIDs.contains(video.id) {
                                        selectedVideoIDs.remove(video.id)
                                    } else {
                                        selectedVideoIDs.insert(video.id)
                                    }
                                }
                            } else {
                                selectedVideo = video
                            }
                        } label: {
                            videoGridCell(video)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isEditingGallery {
                    deleteSelectedButton
                }
            }
        }
    }

    private func photoGridCell(_ photo: CreatorPhoto) -> some View {
        let selected = selectedPhotoIDs.contains(photo.id)

        return ZStack(alignment: .topTrailing) {
            LocalPhotoImage(localURL: vm.localFiles[photo.id], reloadToken: vm.imageRefreshID)
                .frame(height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(CreatorTheme.warmCream.opacity(0.92))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(CreatorTheme.hotPink.opacity(0.18), lineWidth: 1)
                }
                .overlay {
                    if isEditingGallery {
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(Color.black.opacity(selected ? 0.08 : 0.22))
                    }
                }
                .overlay {
                    if isEditingGallery && selected {
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .stroke(CreatorTheme.hotPink, lineWidth: 4)
                    }
                }

            Text("#\(photo.id)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(CreatorTheme.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(CreatorTheme.warmCream.opacity(0.9))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(CreatorTheme.hotPink.opacity(0.32), lineWidth: 1)
                }
                .padding(7)

            if isEditingGallery {
                selectionIcon(selected: selected)
            }
        }
    }

    private func videoGridCell(_ video: CreatorVideo) -> some View {
        let selected = selectedVideoIDs.contains(video.id)

        return ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CreatorTheme.hotPink.opacity(0.86),
                            CreatorTheme.rose.opacity(0.74),
                            CreatorTheme.pinkMist.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 116)
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(CreatorTheme.warmCream.opacity(0.92))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(CreatorTheme.hotPink.opacity(0.18), lineWidth: 1)
                }
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 26, weight: .bold))

                        Text(formatFileSize(video.size))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                }
                .overlay {
                    if isEditingGallery {
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(Color.black.opacity(selected ? 0.08 : 0.22))
                    }
                }
                .overlay {
                    if isEditingGallery && selected {
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .stroke(CreatorTheme.hotPink, lineWidth: 4)
                    }
                }

            Text("#\(video.id)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(CreatorTheme.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(CreatorTheme.warmCream.opacity(0.9))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(CreatorTheme.hotPink.opacity(0.32), lineWidth: 1)
                }
                .padding(7)

            if isEditingGallery {
                selectionIcon(selected: selected)
            }
        }
    }

    private func selectionIcon(selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(selected ? CreatorTheme.hotPink : .white)
            .shadow(color: .black.opacity(0.25), radius: 5)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var deleteSelectedButton: some View {
        Button(role: .destructive) {
            showDeleteSelectedAlert = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text(selectedCountForCurrentTab == 0 ? "Select Items to Delete" : "Delete Selected")
            }
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(selectedCountForCurrentTab == 0 ? Color.gray.opacity(0.35) : Color.red.opacity(0.85))
        )
        .disabled(selectedCountForCurrentTab == 0)
        .padding(.top, 8)
    }

    private func emptyState(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(CreatorTheme.hotPink.opacity(0.8))

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(CreatorTheme.ink)

            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(CreatorTheme.muted)
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CreatorTheme.card.opacity(0.78))
        )
    }
}

// MARK: - Detail Views
