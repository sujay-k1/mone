import Foundation
import SwiftData

enum FinancialDataCloudError: Error {
    case notAuthenticated
    case noLocalFinancialData
    case noCloudFinancialData
}

struct UserFinancialDataUpsert: Encodable {
    let userId: UUID
    let personaId: String
    let processedPayload: FinancialDataBackupPayload
    let dataVersion: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case personaId = "persona_id"
        case processedPayload = "processed_payload"
        case dataVersion = "data_version"
    }
}

struct UserFinancialDataRow: Decodable {
    let userId: UUID
    let personaId: String
    let processedPayload: FinancialDataBackupPayload
    let dataVersion: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case personaId = "persona_id"
        case processedPayload = "processed_payload"
        case dataVersion = "data_version"
    }
}

@MainActor
final class FinancialDataCloudService {

    func backupLatestLocalData(modelContext: ModelContext) async throws {
        guard let userId = supabase.auth.currentSession?.user.id else {
            throw FinancialDataCloudError.notAuthenticated
        }

        let store = IntelligencePersistenceStore(modelContext: modelContext)

        guard let backup = try store.exportLatestBackup() else {
            throw FinancialDataCloudError.noLocalFinancialData
        }

        let row = UserFinancialDataUpsert(
            userId: userId,
            personaId: backup.persona.id,
            processedPayload: backup,
            dataVersion: backup.dataVersion
        )

        _ = try await supabase
            .from("user_financial_data")
            .upsert(row)
            .execute()
    }

    func restoreLatestCloudData(modelContext: ModelContext) async throws -> Bool {
        guard let userId = supabase.auth.currentSession?.user.id else {
            throw FinancialDataCloudError.notAuthenticated
        }

        let rows: [UserFinancialDataRow] = try await supabase
            .from("user_financial_data")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        guard let row = rows.first else {
            return false
        }

        let store = IntelligencePersistenceStore(modelContext: modelContext)
        try store.restore(from: row.processedPayload)

        return true
    }

    func deleteCloudData() async throws {
        guard let userId = supabase.auth.currentSession?.user.id else {
            throw FinancialDataCloudError.notAuthenticated
        }

        _ = try await supabase
            .from("user_financial_data")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
}
