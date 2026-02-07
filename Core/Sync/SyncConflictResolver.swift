#if ENABLE_SYNC

    import CloudKit
    import Foundation
    import os.log

    /// Resolves sync conflicts using timestamp-based last-write-wins strategy
    struct SyncConflictResolver: Sendable {
        private static let logger = Logger(subsystem: "com.saneclip.app", category: "SyncConflict")

        /// Resolve a conflict between client and server records.
        /// Strategy: newest timestamp wins. If timestamps are equal, server wins.
        /// Returns the merged record ready for re-upload, or nil if server should win.
        static func resolve(
            clientRecord: CKRecord,
            serverRecord: CKRecord
        ) -> CKRecord? {
            let clientTimestamp = clientRecord["timestamp"] as? Date ?? .distantPast
            let serverTimestamp = serverRecord["timestamp"] as? Date ?? .distantPast

            if clientTimestamp > serverTimestamp {
                // Client wins — copy client fields onto server record (preserves server change tag)
                let merged = serverRecord
                for key in clientRecord.allKeys() {
                    merged[key] = clientRecord[key]
                }
                logger.info("Conflict resolved: client wins (client=\(clientTimestamp), server=\(serverTimestamp))")
                return merged
            } else {
                // Server wins (or tie) — accept server version, no re-upload needed
                logger.info("Conflict resolved: server wins (client=\(clientTimestamp), server=\(serverTimestamp))")
                return nil
            }
        }
    }

#endif
