//
//  QueueView.swift
//  App-music
//
//  Download Queue View - Real-time queue management with automatic polling
//

import SwiftUI
import SwiftData

struct QueueView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Query for all queue items sorted by position
    @Query(
        sort: \QueueItem.position,
        order: .forward
    ) private var allQueueItems: [QueueItem]
    
    @State private var isRefreshing = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var selectedItem: QueueItem?
    @State private var showPrioritySheet = false
    @State private var queueStats: QueueStats?
    
    private let queueService = QueueService.shared
    
    // Filter active and completed items
    private var activeItems: [QueueItem] {
        allQueueItems.filter { !$0.isCompleted }
    }
    
    private var completedItems: [QueueItem] {
        allQueueItems.filter { $0.isCompleted }
    }
    
    private var downloadingItems: [QueueItem] {
        allQueueItems.filter { $0.statusEnum == .downloading }
    }
    
    var body: some View {
        ZStack {
            // Animated background
            AnimatedBackgroundView()
                .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: DesignTokens.spacingXL) {
                        // Spacer for top padding
                        Spacer()
                            .frame(height: DesignTokens.spacingSM)
                        
                        // Queue Stats Card
                        queueStatsCard
                        
                        // Batch Actions
                        if !activeItems.isEmpty {
                            batchActionsCard
                        }
                        
                        // Active Queue Items
                        if !activeItems.isEmpty {
                            activeQueueSection
                        } else {
                            emptyQueueState
                        }
                        
                        // Completed Items Section
                        if !completedItems.isEmpty {
                            completedSection
                        }
                        
                        // Bottom spacer for mini player
                        Spacer()
                            .frame(height: DesignTokens.spacing2XL)
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                }
                .navigationTitle("Queue")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if queueService.isPolling {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Syncing")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                        }
                    }
                }
                .refreshable {
                    await refreshQueue()
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                    }
                }
                .sheet(item: $selectedItem) { item in
                    QueueItemDetailSheet(item: item, onPriorityChange: { newPriority in
                        Task {
                            await changePriority(item: item, priority: newPriority)
                        }
                    })
                }
            }
        }
        .onAppear {
            // Force initial sync to trigger backfill
            Task {
                do {
                    print("📱 QueueView appeared - forcing initial sync...")
                    try await queueService.syncQueue(modelContext: modelContext)
                } catch {
                    print("❌ Initial sync failed: \(error)")
                }
            }

            // Start polling when view appears
            queueService.startPolling(modelContext: modelContext)
            updateStats()
        }
        .onDisappear {
            // Stop polling when view disappears (optional - queue continues in background)
            // queueService.stopPolling()
        }
        .onChange(of: allQueueItems.count) {
            updateStats()
        }
    }
    
    // MARK: - Queue Stats Card
    
    private var queueStatsCard: some View {
        HStack(spacing: DesignTokens.spacingLG) {
            // Downloading count
            VStack(spacing: DesignTokens.spacingXS) {
                Text("\(downloadingItems.count)")
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .foregroundStyle(DesignTokens.accentPrimary)
                
                Text("Downloading")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 60)
            
            // Active count (pending + downloading)
            VStack(spacing: DesignTokens.spacingXS) {
                Text("\(activeItems.count)")
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .foregroundStyle(DesignTokens.warning)
                
                Text("Active")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 60)
            
            // Completed count
            VStack(spacing: DesignTokens.spacingXS) {
                Text("\(completedItems.count)")
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .foregroundStyle(DesignTokens.success)
                
                Text("Done")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
        }
        .minimalistCard(
            cornerRadius: DesignTokens.cornerRadiusLarge,
            padding: DesignTokens.spacingLG
        )
    }
    
    // MARK: - Batch Actions
    
    private var batchActionsCard: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            HStack(spacing: DesignTokens.spacingSM) {
                // Pause All
                Button {
                    Task { await pauseAll() }
                } label: {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "pause.circle")
                        Text("Pause")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DesignTokens.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingSM)
                }
                .outlineButtonStyle()
                
                // Resume All
                Button {
                    Task { await resumeAll() }
                } label: {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "play.circle")
                        Text("Resume")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DesignTokens.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingSM)
                }
                .outlineButtonStyle()
            }
            
            // Clear Completed
            if !completedItems.isEmpty {
                Button {
                    Task { await clearCompleted() }
                } label: {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "trash.circle")
                        Text("Clear Completed (\(completedItems.count))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DesignTokens.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingSM)
                }
                .outlineButtonStyle(borderColor: DesignTokens.error)
            }
        }
    }
    
    // MARK: - Active Queue Section
    
    private var activeQueueSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("Active Downloads")
                .font(.system(size: 36, weight: .thin, design: .rounded))
                .foregroundStyle(DesignTokens.textPrimary)
            
            ForEach(activeItems) { item in
                QueueItemRow(
                    item: item,
                    onPause: { Task { await pauseItem(item) } },
                    onResume: { Task { await resumeItem(item) } },
                    onDelete: { Task { await deleteItem(item) } },
                    onTap: { selectedItem = item }
                )
                .onAppear {
                    print("📋 ACTIVE item appeared: \(item.backendId ?? "unknown"), status: \(item.status), canPause: \(item.canPause), canResume: \(item.canResume)")
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyQueueState: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: "tray")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(DesignTokens.textSecondary)
            
            Text("Queue is Empty")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(DesignTokens.textPrimary)
            
            Text("Add items from the Download tab\nto start building your queue")
                .font(.subheadline)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacing2XL)
        .minimalistCard(
            cornerRadius: DesignTokens.cornerRadiusLarge,
            padding: DesignTokens.spacingXL
        )
    }
    
    // MARK: - Completed Section
    
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            HStack {
                Text("Completed")
                    .font(.system(size: 28, weight: .thin, design: .rounded))
                    .foregroundStyle(DesignTokens.textSecondary)
                
                Spacer()
            }
            
            ForEach(completedItems) { item in
                QueueItemRow(
                    item: item,
                    onPause: { },
                    onResume: { },
                    onDelete: { Task { await deleteItem(item) } },
                    onTap: { selectedItem = item }
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func refreshQueue() async {
        isRefreshing = true
        
        do {
            try await queueService.syncQueue(modelContext: modelContext)
            updateStats()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isRefreshing = false
    }
    
    private func pauseItem(_ item: QueueItem) async {
        print("⏸️ Attempting to pause item \(item.backendId ?? "unknown")")
        do {
            try await queueService.pauseItem(item: item, modelContext: modelContext)
            print("⏸️ Successfully paused item")
        } catch let error as APIError {
            print("❌ Pause failed (APIError): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            print("❌ Pause failed (generic): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func resumeItem(_ item: QueueItem) async {
        print("▶️ Attempting to resume item \(item.backendId ?? "unknown")")
        do {
            try await queueService.resumeItem(item: item, modelContext: modelContext)
            print("▶️ Successfully resumed item")
        } catch let error as APIError {
            print("❌ Resume failed (APIError): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            print("❌ Resume failed (generic): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func deleteItem(_ item: QueueItem) async {
        do {
            try await queueService.removeFromQueue(item: item, modelContext: modelContext)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func pauseAll() async {
        do {
            try await queueService.pauseAll(modelContext: modelContext)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func resumeAll() async {
        do {
            try await queueService.resumeAll(modelContext: modelContext)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func clearCompleted() async {
        do {
            try await queueService.clearCompleted(modelContext: modelContext)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func changePriority(item: QueueItem, priority: QueuePriority) async {
        do {
            try await queueService.updatePriority(item: item, priority: priority, modelContext: modelContext)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func updateStats() {
        do {
            queueStats = try queueService.getQueueStats(modelContext: modelContext)
        } catch {
            print("Failed to update stats: \(error)")
        }
    }
}

// MARK: - Queue Item Row Component

struct QueueItemRow: View {
    let item: QueueItem
    let onPause: () -> Void
    let onResume: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.spacingSM) {
                // Thumbnail
                thumbnailView
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(item.title ?? "Unknown Title")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(1)
                    
                    // Artist
                    Text(item.artist ?? "Unknown Artist")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(1)
                    
                    // Status and priority
                    HStack(spacing: DesignTokens.spacingXS) {
                        priorityBadge(item.priorityEnum)
                        
                        Text(item.statusText)
                            .font(.caption)
                            .foregroundStyle(statusColor(item.statusEnum))
                    }
                    
                    // Progress bar (only for downloading)
                    if item.statusEnum == .downloading {
                        ProgressView(value: item.progress)
                            .customProgressStyle(tint: DesignTokens.accentPrimary, height: 3)
                    }
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding(DesignTokens.spacingSM)
            .background(DesignTokens.glassBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge)
                    .stroke(
                        item.statusEnum == .downloading 
                            ? DesignTokens.accentPrimary.opacity(0.3)
                            : DesignTokens.glassBorder, 
                        lineWidth: item.statusEnum == .downloading ? 2 : 1
                    )
            )
            .cornerRadius(DesignTokens.cornerRadiusLarge)
        }
        .buttonStyle(.plain)
    }
    
    private var thumbnailView: some View {
        Group {
            if let thumbnailURL = item.thumbnailURL,
               let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        placeholderThumbnail
                    case .empty:
                        placeholderThumbnail
                            .overlay {
                                ProgressView()
                                    .tint(DesignTokens.textSecondary)
                            }
                    @unknown default:
                        placeholderThumbnail
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall))
            } else {
                placeholderThumbnail
            }
        }
    }
    
    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall)
            .fill(DesignTokens.backgroundTertiary)
            .frame(width: 64, height: 64)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(DesignTokens.textSecondary)
            }
    }
    
    private var actionButtons: some View {
        HStack(spacing: DesignTokens.spacingXS) {
            // Pause/Resume button
            if item.canPause {
                Button(action: {
                    print("🔘 PAUSE BUTTON CLICKED! Item: \(item.backendId ?? "unknown"), Status: \(item.status)")
                    onPause()
                }) {
                    Image(systemName: "pause.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DesignTokens.warning)
                }
                .buttonStyle(.plain)
                .onAppear {
                    print("⏸️ PAUSE button appeared for item: \(item.backendId ?? "unknown"), status: \(item.status)")
                }
            } else if item.canResume {
                Button(action: {
                    print("🔘 RESUME BUTTON CLICKED! Item: \(item.backendId ?? "unknown"), Status: \(item.status)")
                    onResume()
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DesignTokens.success)
                }
                .buttonStyle(.plain)
                .onAppear {
                    print("▶️ RESUME button appeared for item: \(item.backendId ?? "unknown"), status: \(item.status)")
                }
            }
            
            // Delete button
            if item.canDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DesignTokens.error)
                }
                .buttonStyle(.plain)
            }
            
            // Position badge for active items
            if !item.isCompleted {
                Text("#\(item.position)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignTokens.accentPrimary.opacity(0.3))
                    .cornerRadius(8)
            }
        }
    }
    
    private func priorityBadge(_ priority: QueuePriority) -> some View {
        Text(priority.displayName)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor(priority))
            .cornerRadius(4)
    }
    
    private func priorityColor(_ priority: QueuePriority) -> Color {
        switch priority {
        case .high: return DesignTokens.error
        case .normal: return DesignTokens.accentPrimary
        case .low: return DesignTokens.textSecondary
        }
    }
    
    private func statusColor(_ status: QueueItemStatus) -> Color {
        switch status {
        case .pending: return DesignTokens.textSecondary
        case .downloading: return DesignTokens.accentPrimary
        case .completed: return DesignTokens.success
        case .failed: return DesignTokens.error
        case .paused: return DesignTokens.warning
        }
    }
}

// MARK: - Queue Item Detail Sheet

struct QueueItemDetailSheet: View {
    let item: QueueItem
    let onPriorityChange: (QueuePriority) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPriority: QueuePriority
    
    init(item: QueueItem, onPriorityChange: @escaping (QueuePriority) -> Void) {
        self.item = item
        self.onPriorityChange = onPriorityChange
        _selectedPriority = State(initialValue: item.priorityEnum)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.spacingLG) {
                        // Thumbnail
                        if let thumbnailURL = item.thumbnailURL,
                           let url = URL(string: thumbnailURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(DesignTokens.backgroundTertiary)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                            .frame(height: 200)
                            .cornerRadius(DesignTokens.cornerRadiusMedium)
                        }
                        
                        // Details
                        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                            DetailRow(title: "Title", value: item.title ?? "Unknown")
                            DetailRow(title: "Artist", value: item.artist ?? "Unknown")
                            DetailRow(title: "Format", value: item.format.uppercased())
                            DetailRow(title: "Status", value: item.statusEnum.displayName)
                            
                            if let duration = item.duration {
                                DetailRow(title: "Duration", value: formatDuration(duration))
                            }
                            
                            if item.progress > 0 && item.statusEnum == .downloading {
                                DetailRow(title: "Progress", value: "\(item.progressPercentage)%")
                                
                                ProgressView(value: item.progress)
                                    .customProgressStyle()
                                    .padding(.vertical, DesignTokens.spacingXS)
                            }
                            
                            if let error = item.errorMessage {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Error")
                                        .font(.subheadline)
                                        .foregroundStyle(DesignTokens.textSecondary)
                                    Text(error)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(DesignTokens.error)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            Divider()
                                .padding(.vertical, DesignTokens.spacingSM)
                            
                            // Priority Picker
                            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                                Text("Priority")
                                    .font(.subheadline)
                                    .foregroundStyle(DesignTokens.textSecondary)
                                
                                Picker("Priority", selection: $selectedPriority) {
                                    ForEach(QueuePriority.allCases, id: \.self) { priority in
                                        Text(priority.displayName).tag(priority)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .disabled(item.statusEnum == .downloading || item.isCompleted)
                                .onChange(of: selectedPriority) { _, newValue in
                                    if newValue != item.priorityEnum {
                                        onPriorityChange(newValue)
                                    }
                                }
                            }
                        }
                        .minimalistCard(
                            cornerRadius: DesignTokens.cornerRadiusLarge,
                            padding: DesignTokens.spacingMD
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Queue Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(DesignTokens.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: QueueItem.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    // Add sample queue items
    let item1 = QueueItem(
        url: "https://youtube.com/watch?v=test1",
        format: "mp3",
        priority: .high,
        title: "Bohemian Rhapsody",
        artist: "Queen",
        thumbnailURL: "https://i.ytimg.com/vi/test/maxresdefault.jpg",
        duration: 355
    )
    item1.statusEnum = .downloading
    item1.progress = 0.65
    item1.position = 1
    
    let item2 = QueueItem(
        url: "https://youtube.com/watch?v=test2",
        format: "m4a",
        priority: .normal,
        title: "Stairway to Heaven",
        artist: "Led Zeppelin",
        duration: 482
    )
    item2.position = 2
    
    let item3 = QueueItem(
        url: "https://youtube.com/watch?v=test3",
        format: "mp3",
        priority: .low,
        title: "Hotel California",
        artist: "Eagles",
        duration: 391
    )
    item3.statusEnum = .completed
    item3.position = 3
    
    context.insert(item1)
    context.insert(item2)
    context.insert(item3)
    
    return QueueView()
        .modelContainer(container)
}
