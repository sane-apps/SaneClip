#if ENABLE_SYNC

    import CloudKit
    import CryptoKit
    import Foundation

    /// Maps SharedClipboardItem ↔ CKRecord with optional E2E encryption
    struct SyncDataModel: Sendable {
        static let recordType = "ClipboardItem"
        static let zoneName = "ClipboardItems"
        static let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        // MARK: - CKRecord Field Keys

        private enum Field {
            static let content = "content"
            static let contentType = "contentType"
            static let timestamp = "timestamp"
            static let sourceAppBundleID = "sourceAppBundleID"
            static let sourceAppName = "sourceAppName"
            static let pasteCount = "pasteCount"
            static let deviceId = "deviceId"
            static let deviceName = "deviceName"
            static let encrypted = "encrypted"
        }

        // MARK: - Encode to CKRecord

        /// Convert a SharedClipboardItem to a CKRecord for CloudKit upload.
        /// If encryption is enabled, the content field is encrypted with AES-GCM.
        static func encode(_ item: SharedClipboardItem, encrypt: Bool) throws -> CKRecord {
            let recordID = CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID)
            let record = CKRecord(recordType: recordType, recordID: recordID)

            // Encode content
            let contentData = try JSONEncoder().encode(item.content)
            if encrypt {
                let encryptedData = try HistoryEncryption.encrypt(contentData)
                record[Field.content] = encryptedData as NSData
                record[Field.encrypted] = 1 as NSNumber
            } else {
                record[Field.content] = contentData as NSData
                record[Field.encrypted] = 0 as NSNumber
            }

            // Content type hint (unencrypted, for server-side filtering)
            switch item.content {
            case .text: record[Field.contentType] = "text"
            case .imageData: record[Field.contentType] = "image"
            }

            record[Field.timestamp] = item.timestamp as NSDate
            record[Field.sourceAppBundleID] = item.sourceAppBundleID as NSString?
            record[Field.sourceAppName] = item.sourceAppName as NSString?
            record[Field.pasteCount] = item.pasteCount as NSNumber
            record[Field.deviceId] = item.deviceId as NSString
            record[Field.deviceName] = item.deviceName as NSString

            return record
        }

        // MARK: - Decode from CKRecord

        /// Convert a CKRecord from CloudKit into a SharedClipboardItem.
        /// Decrypts content if the encrypted flag is set.
        static func decode(_ record: CKRecord) throws -> SharedClipboardItem {
            guard record.recordType == recordType else {
                throw SyncError.wrongRecordType(record.recordType)
            }

            guard let contentData = record[Field.content] as? Data else {
                throw SyncError.missingField(Field.content)
            }

            let isEncrypted = (record[Field.encrypted] as? Int) == 1

            let content: SharedClipboardContent
            if isEncrypted {
                let decryptedData = try HistoryEncryption.decrypt(contentData)
                content = try JSONDecoder().decode(SharedClipboardContent.self, from: decryptedData)
            } else {
                content = try JSONDecoder().decode(SharedClipboardContent.self, from: contentData)
            }

            guard let timestamp = record[Field.timestamp] as? Date else {
                throw SyncError.missingField(Field.timestamp)
            }

            guard let id = UUID(uuidString: record.recordID.recordName) else {
                throw SyncError.invalidRecordID(record.recordID.recordName)
            }

            return SharedClipboardItem(
                id: id,
                content: content,
                timestamp: timestamp,
                sourceAppBundleID: record[Field.sourceAppBundleID] as? String,
                sourceAppName: record[Field.sourceAppName] as? String,
                pasteCount: (record[Field.pasteCount] as? Int) ?? 0,
                deviceId: (record[Field.deviceId] as? String) ?? "",
                deviceName: (record[Field.deviceName] as? String) ?? ""
            )
        }

        // MARK: - Errors

        enum SyncError: Error, LocalizedError {
            case wrongRecordType(String)
            case missingField(String)
            case invalidRecordID(String)

            var errorDescription: String? {
                switch self {
                case let .wrongRecordType(type): "Unexpected record type: \(type)"
                case let .missingField(field): "Missing required field: \(field)"
                case let .invalidRecordID(id): "Invalid record ID: \(id)"
                }
            }
        }
    }

#endif
