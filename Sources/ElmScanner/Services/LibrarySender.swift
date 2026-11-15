import CloudKit
import Foundation

/// Where a freshly looked-up book goes after it is scanned.
@MainActor
protocol LibrarySending: AnyObject {
    func send(_ metadata: BookMetadata)
}

/// Sends each scanned book to ElmLibrary through CloudKit.
///
/// One `ScannedBook` record per book goes into the `ScannedBooks` zone of the
/// user's private database in the iCloud container shared with ElmLibrary,
/// which takes the books in and clears the zone (see ElmLibrary's
/// `ScannerInbox`, which documents the same record layout). The record name
/// comes from the ISBN-13, so scanning a book again just updates its record.
///
/// A book that can't be sent (offline, not signed in to iCloud) is kept and
/// tried again at the next scan and when the app returns to the foreground.
/// Turn it off with `enabledKey` (Settings on the Mac, About on the iPhone).
@MainActor
final class LibrarySender: LibrarySending {
    static let enabledKey = "sendToElmLibrary"
    static let recordType = "ScannedBook"
    static let zoneName = "ScannedBooks"
    static let pendingKey = "pendingLibraryBooks"

    /// The sender the apps use. Nil in the direct-download build, which has
    /// no iCloud entitlement.
    static let shared: LibrarySender? = {
        #if DIRECT_DOWNLOAD
        return nil
        #else
        return LibrarySender()
        #endif
    }()

    /// The container named by the app's iCloud entitlement.
    private var database: CKDatabase { CKContainer.default().privateCloudDatabase }
    private var zoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName) }
    private var zoneReady = false
    private var sending = false

    private(set) var pending: [BookMetadata] = LibrarySender.loadPending()

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    func send(_ metadata: BookMetadata) {
        guard isEnabled else { return }
        pending.removeAll { Self.recordName(for: $0) == Self.recordName(for: metadata) }
        pending.append(metadata)
        savePending()
        Task { await flush() }
    }

    /// Tries to send everything still waiting.
    func flush() async {
        guard isEnabled, !sending, !pending.isEmpty else { return }
        sending = true
        defer { sending = false }
        let batch = pending
        do {
            if !zoneReady {
                _ = try await database.save(CKRecordZone(zoneID: zoneID))
                zoneReady = true
            }
            let records = batch.map { Self.record(for: $0, zoneID: zoneID) }
            _ = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
            // Keep anything added or edited while this was in flight.
            pending.removeAll { sent in batch.contains { $0 == sent } }
            savePending()
        } catch {
            // Offline or not signed in to iCloud: stays pending for next time.
        }
    }

    // MARK: Record layout (mirrored by ElmLibrary's `ScannerRecord`)

    static func recordName(for metadata: BookMetadata) -> String {
        "isbn-" + (ISBN.canonical13(metadata.isbn) ?? metadata.isbn)
    }

    static func record(for metadata: BookMetadata, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: recordName(for: metadata), zoneID: zoneID))
        record["isbn"] = metadata.isbn
        record["title"] = metadata.title
        record["subtitle"] = metadata.subtitle
        record["authors"] = (try? JSONEncoder().encode(metadata.authors)).flatMap { String(data: $0, encoding: .utf8) }
        record["publisher"] = metadata.publisher
        record["place"] = metadata.place
        record["publicationYear"] = metadata.publicationYear.map(Int64.init)
        record["numberOfPages"] = metadata.numberOfPages
        record["url"] = metadata.url
        record["tags"] = metadata.tags
        return record
    }

    // MARK: Pending books on disk

    private static func loadPending() -> [BookMetadata] {
        UserDefaults.standard.data(forKey: pendingKey)
            .flatMap { try? JSONDecoder().decode([BookMetadata].self, from: $0) } ?? []
    }

    private func savePending() {
        UserDefaults.standard.set(try? JSONEncoder().encode(pending), forKey: Self.pendingKey)
    }
}
