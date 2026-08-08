import Foundation
import FirebaseAuth
import FirebaseFirestore

struct RemoteUserState {
    let onboardingData: OnboardingData?
    let profile: UserProfile?
    let routine: AIRoutineOutput?
    let faceScanResult: FaceScanResult?
    let journalEntries: [JournalEntry]
    let skinLogEntries: [SkinLogEntry]
    let weeklyCheckIns: [WeeklyCheckInData]
    let routineCompletion: [String: [String: Bool]]
}

final class FirestoreSyncService {

    static let shared = FirestoreSyncService()

    private let db = Firestore.firestore()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {}

    var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    var currentUserEmail: String? {
        Auth.auth().currentUser?.email
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> FirebaseAuth.User {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }

    func signInAnonymouslyIfNeeded() async throws -> FirebaseAuth.User {
        if let user = Auth.auth().currentUser { return user }
        let result = try await Auth.auth().signInAnonymously()
        return result.user
    }

    func userDocumentExists(uid: String) async throws -> Bool {
        try await userDocument(uid: uid).getDocument().exists
    }

    func upsertUserShell(name: String, isGuest: Bool) {
        guard let uid = currentUserID else { return }
        var data: [String: Any] = [
            "uid": uid,
            "name": name,
            "isGuest": isGuest,
            "email": currentUserEmail ?? "",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        data["createdAt"] = FieldValue.serverTimestamp()
        userDocument(uid: uid).setData(data, merge: true)
    }

    func saveOnboardingProgress(_ onboardingData: OnboardingData, completed: Bool = false) {
        guard let uid = currentUserID, let payload = dictionary(from: onboardingData) else { return }
        userDocument(uid: uid).setData([
            "onboardingData": payload,
            "onboardingCompleted": completed,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func saveProfile(_ profile: UserProfile) {
        guard let uid = currentUserID, let payload = dictionary(from: profile) else { return }
        userDocument(uid: uid).setData([
            "profile": payload,
            "onboardingCompleted": true,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func saveRoutine(_ routine: AIRoutineOutput, reason: String? = nil, date: Date = Date()) {
        guard let uid = currentUserID, let payload = dictionary(from: routine) else { return }
        let metadata: [String: Any] = [
            "reason": reason ?? "",
            "dateKey": dateKey(date),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        userDocument(uid: uid).collection("routines").document("current")
            .setData(payload.merging(metadata) { current, _ in current }, merge: true)
        userDocument(uid: uid).collection("dailyRoutines").document(dateKey(date))
            .setData(payload.merging(metadata) { current, _ in current }, merge: true)
    }

    func saveFaceScanResult(_ result: FaceScanResult) {
        guard let uid = currentUserID, let payload = dictionary(from: result) else { return }
        userDocument(uid: uid).collection("faceScans").document("latest")
            .setData(payload.merging(["updatedAt": FieldValue.serverTimestamp()]) { current, _ in current }, merge: true)
    }

    func saveJournalEntry(_ entry: JournalEntry) {
        guard let uid = currentUserID, let payload = dictionary(from: entry) else { return }
        userDocument(uid: uid).collection("journalEntries").document(entry.id)
            .setData(payload.merging(["updatedAt": FieldValue.serverTimestamp()]) { current, _ in current }, merge: true)
    }

    func deleteJournalEntry(id: String) {
        guard let uid = currentUserID else { return }
        userDocument(uid: uid).collection("journalEntries").document(id).delete()
    }

    func saveSkinLogEntry(_ entry: SkinLogEntry) {
        guard let uid = currentUserID, let payload = dictionary(from: entry) else { return }
        userDocument(uid: uid).collection("skinLogEntries").document(entry.id)
            .setData(payload.merging(["updatedAt": FieldValue.serverTimestamp()]) { current, _ in current }, merge: true)
    }

    func deleteSkinLogEntry(id: String) {
        guard let uid = currentUserID else { return }
        userDocument(uid: uid).collection("skinLogEntries").document(id).delete()
    }

    func saveWeeklyCheckIn(_ data: WeeklyCheckInData) {
        guard let uid = currentUserID, let payload = dictionary(from: data), !data.weekKey.isEmpty else { return }
        userDocument(uid: uid).collection("weeklyCheckIns").document(data.weekKey)
            .setData(payload.merging(["updatedAt": FieldValue.serverTimestamp()]) { current, _ in current }, merge: true)
    }

    func saveRoutineCompletion(_ completion: [String: [String: Bool]]) {
        guard let uid = currentUserID else { return }
        userDocument(uid: uid).collection("progress").document("routineCompletion")
            .setData([
                "days": completion,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    func loadTodayRoutine(date: Date = Date()) async throws -> AIRoutineOutput? {
        guard let uid = currentUserID else { return nil }
        let today = try await userDocument(uid: uid).collection("dailyRoutines").document(dateKey(date)).getDocument()
        if let routine = decode(AIRoutineOutput.self, from: today.data()) {
            return routine
        }
        let current = try await userDocument(uid: uid).collection("routines").document("current").getDocument()
        guard let routine = decode(AIRoutineOutput.self, from: current.data()) else { return nil }
        saveRoutine(routine, reason: "Reused active routine for \(dateKey(date))", date: date)
        return routine
    }

    func loadUserState() async throws -> RemoteUserState {
        guard let uid = currentUserID else {
            return RemoteUserState(onboardingData: nil, profile: nil, routine: nil, faceScanResult: nil, journalEntries: [], skinLogEntries: [], weeklyCheckIns: [], routineCompletion: [:])
        }

        let user = try await userDocument(uid: uid).getDocument().data()
        let routine = try await userDocument(uid: uid).collection("routines").document("current").getDocument().data()
        let faceScan = try await userDocument(uid: uid).collection("faceScans").document("latest").getDocument().data()
        let journal = try await userDocument(uid: uid).collection("journalEntries").getDocuments().documents
        let skinLogs = try await userDocument(uid: uid).collection("skinLogEntries").getDocuments().documents
        let checkIns = try await userDocument(uid: uid).collection("weeklyCheckIns").getDocuments().documents
        let completion = try await userDocument(uid: uid).collection("progress").document("routineCompletion").getDocument().data()

        return RemoteUserState(
            onboardingData: decode(OnboardingData.self, from: user?["onboardingData"]),
            profile: decode(UserProfile.self, from: user?["profile"]),
            routine: decode(AIRoutineOutput.self, from: routine),
            faceScanResult: decode(FaceScanResult.self, from: faceScan),
            journalEntries: journal.compactMap { decode(JournalEntry.self, from: $0.data()) }.sorted { $0.date > $1.date },
            skinLogEntries: skinLogs.compactMap { decode(SkinLogEntry.self, from: $0.data()) }.sorted { $0.date > $1.date },
            weeklyCheckIns: checkIns.compactMap { decode(WeeklyCheckInData.self, from: $0.data()) }.sorted { $0.weekStart > $1.weekStart },
            routineCompletion: (completion?["days"] as? [String: [String: Bool]]) ?? [:]
        )
    }

    private func userDocument(uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    private func dictionary<T: Encodable>(from value: T) -> [String: Any]? {
        guard
            let data = try? encoder.encode(value),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }

    private func decode<T: Decodable>(_ type: T.Type, from object: Any?) -> T? {
        guard
            let object = sanitizedJSONValue(object),
            JSONSerialization.isValidJSONObject(object),
            let data = try? JSONSerialization.data(withJSONObject: object)
        else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func sanitizedJSONValue(_ value: Any?) -> Any? {
        switch value {
        case let dict as [String: Any]:
            return dict.reduce(into: [String: Any]()) { result, element in
                if let value = sanitizedJSONValue(element.value) {
                    result[element.key] = value
                }
            }
        case let array as [Any]:
            return array.compactMap { sanitizedJSONValue($0) }
        case let timestamp as Timestamp:
            return ISO8601DateFormatter().string(from: timestamp.dateValue())
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case Optional<Any>.none:
            return nil
        default:
            return nil
        }
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
