// AppDataModel.swift
// Singleton data layer — use AppDataModel.shared throughout the app.
// dataModel.swift and Models.swift are preserved and untouched.

import Foundation

extension Notification.Name {
    static let routineCompletionDidChange = Notification.Name("routineCompletionDidChange")
}

// MARK: - SkinConcern

enum SkinConcern: String, CaseIterable, Codable {
    case acne
    case darkSpots
    case darkCircles
    case foreheadBumps
    case blackheads
    case whiteheads
    case redness
    case fineLines
    case pigmentation

    // Property: user readable label for the UI
    var displayName: String {
        switch self {
        case .acne:          return "Acne"
        case .darkSpots:     return "Dark Spots"
        case .darkCircles:   return "Dark Circles"
        case .foreheadBumps: return "Forehead Bumps"
        case .blackheads:    return "Blackheads"
        case .whiteheads:    return "Whiteheads"
        case .redness:       return "Redness"
        case .fineLines:     return "Fine Lines"
        case .pigmentation:  return "Pigmentation"
        }
    }
}

// MARK: - UserProfile

// everything the user sets durinonboarding, plus concerns detected by the face scan later.
struct UserProfile: Codable {

    var name: String
    var birthYear: Int?
    var tZone: SkinType
    var uZone: SkinType
    var cZone: SkinType
    var sensitivity: SensitivityLevel
    var uvExposure: UVExposureLevel
    var goals: [SkinGoal]
    var concerns: [SkinConcern]

    var age: Int? {
        guard let birthYear else { return nil }
        return Calendar.current.component(.year, from: Date()) - birthYear
    }

    var dominantSkinType: SkinType {
        let types = [tZone, uZone, cZone]
        let grouped = Dictionary(grouping: types) { $0 }.mapValues { $0.count }
        return grouped.max(by: { $0.value < $1.value })?.key ?? .normal
    }
}

// MARK: - UserProfile Persistence

extension UserProfile {

    private static let defaultsKey = "app_user_profile_v1"
    
    //  Simple User defaults read/write/delete.
    static func load() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    static func from(onboarding: OnboardingData, name: String) -> UserProfile? {
        guard
            let tZone      = onboarding.tZone,
            let uZone      = onboarding.uZone,
            let cZone      = onboarding.cZone,
            let sensitivity = onboarding.sensitivity,
            let uvExposure  = onboarding.uvExposure
        else { return nil } // onboarding not completed

        return UserProfile(
            name: name,
            birthYear: onboarding.birthYear,
            tZone: tZone,
            uZone: uZone,
            cZone: cZone,
            sensitivity: sensitivity,
            uvExposure: uvExposure,
            goals: onboarding.goals,
            concerns: []
        )
    }
}

// MARK: - SavedRoutine

// When the AI generates a routine, the user can save it with a custom name. (e.g. "My Winter Routine")
struct SavedRoutine: Codable {

    let id: String  // to delete a specific routine later
    let name: String
    let createdAt: Date     // can search n sort for routine
    let morning: [AIRoutineStep]
    let evening: [AIRoutineStep]

    //  because id and createdAt must be generated at creation
    init(name: String, from output: AIRoutineOutput) {
        self.id = UUID().uuidString
        self.name = name
        self.createdAt = Date()
        self.morning = output.morning
        self.evening = output.evening
    }
}

// MARK: - Routine History

struct RoutineHistoryEntry: Codable {
    let id: String
    let title: String
    let changedAt: Date
    let summary: String
    let detail: String?
    let previousRoutine: AIRoutineOutput?
    let newRoutine: AIRoutineOutput?

    init(
        title: String,
        summary: String,
        detail: String? = nil,
        changedAt: Date = Date(),
        previousRoutine: AIRoutineOutput? = nil,
        newRoutine: AIRoutineOutput? = nil
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.changedAt = changedAt
        self.summary = summary
        self.detail = detail
        self.previousRoutine = previousRoutine
        self.newRoutine = newRoutine
    }
}

// MARK: - AppDataModel

final class AppDataModel {

    static let shared = AppDataModel()

    private init() {
        loadStaticData()
        userProfile = UserProfile.load()
        loadJournalEntries()
        loadSavedRoutines()
        loadRoutineHistory()
        aiRoutine = loadAIRoutineFromDisk()
        lastFaceScanResult = loadLastFaceScanResult()
        routineCompletion = loadRoutineCompletion()
    }

    // MARK: Static (JSON-backed, read-only)

    //  Loaded from data.json at startup, never written back.
    private(set) var ingredients: [Ingredient] = []
    private(set) var dailyTip: DailyTip?
    private(set) var skinInsights: [SkinInsight] = []
    private(set) var affirmations: [Affirmation] = []

    // MARK: Live (persisted)
    
    //  User-owned data that changes during the app's lifetime and is saved to disk
    private(set) var userProfile: UserProfile?
    private(set) var journalEntries: [JournalEntry] = []
    private(set) var savedRoutines: [SavedRoutine] = []
    private(set) var routineHistory: [RoutineHistoryEntry] = []
    private(set) var aiRoutine: AIRoutineOutput?
    private(set) var lastFaceScanResult: FaceScanResult?

    // MARK: Session (in-memory)

    private var routineCompletion: [String: [String: Bool]] = [:]

    private let remoteStore = FirestoreSyncService.shared
}

// MARK: - Static Data

private extension AppDataModel {

    func loadStaticData() {
        guard
            let url  = Bundle.main.url(forResource: "data", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let root = try? JSONDecoder().decode(SkinCareRoot.self, from: data)
        else {
            assertionFailure("AppDataModel: failed to load data.json")
            return
        }

        ingredients  = root.ingredients
        dailyTip     = root.dailyTip
        skinInsights = root.skinInsights
        affirmations = root.affirmations
    }
}

// MARK: - Profile

extension AppDataModel {

    func saveProfile(_ profile: UserProfile) {
        profile.save()
        userProfile = profile
        remoteStore.saveProfile(profile)
        if let onboardingData = onboardingDataFromProfile() {
            saveOnboardingProgress(onboardingData, completed: true)
        }
    }

    func updateConcerns(_ concerns: [SkinConcern]) {
        guard var updated = userProfile else { return }
        updated.concerns = concerns
        saveProfile(updated)
    }

    func saveOnboardingProgress(_ onboardingData: OnboardingData, completed: Bool = false) {
        if let data = try? JSONEncoder().encode(onboardingData) {
            UserDefaults.standard.set(data, forKey: "onboardingData")
        }
        remoteStore.saveOnboardingProgress(onboardingData, completed: completed)
    }

    func loadOnboardingProgress() -> OnboardingData? {
        if let data = UserDefaults.standard.data(forKey: "onboardingData"),
           let onboardingData = try? JSONDecoder().decode(OnboardingData.self, from: data) {
            return onboardingData
        }
        return onboardingDataFromProfile()
    }

    func applyRemoteUserState(_ state: RemoteUserState) {
        if let onboardingData = state.onboardingData {
            saveOnboardingProgress(onboardingData, completed: state.profile != nil)
        }
        if let profile = state.profile {
            profile.save()
            userProfile = profile
        }
        if let routine = state.routine {
            if let data = try? JSONEncoder().encode(routine) {
                try? data.write(to: aiRoutineURL)
            }
            aiRoutine = routine
        }
        if let faceScanResult = state.faceScanResult {
            saveLastFaceScanResult(faceScanResult)
        }
        journalEntries = state.journalEntries
        persistJournalEntries()
        routineCompletion = state.routineCompletion
        persistRoutineCompletion()
    }
}

// MARK: - Ingredients

extension AppDataModel {

    func ingredient(forID id: String) -> Ingredient? {
        ingredients.first { $0.id == id }
    }

    func ingredient(named name: String) -> Ingredient? {
        let lower = name.lowercased()
        return ingredients.first {
            $0.name.lowercased() == lower ||
            ($0.aliases?.contains { $0.lowercased() == lower } ?? false)
        }
    }

    func ingredientNames(for step: RoutineStep) -> [String] {
        step.ingredientIDs.compactMap { ingredient(forID: $0)?.name }
    }

    func hasConflict(between ingredientIDs: [String]) -> Bool {
        let selected = ingredients.filter { ingredientIDs.contains($0.id) }
        let selectedIDs = Set(selected.map { $0.id })
        return selected.contains { !Set($0.conflictingWith).isDisjoint(with: selectedIDs) }
    }
    
    func allIngredients() -> [Ingredient] {
        return ingredients
    }
}

// MARK: - Affirmations
// remove 
extension AppDataModel {

    func nextAffirmation() -> Affirmation? {
        guard !affirmations.isEmpty else { return nil }

        let key  = "last_affirmation_id"
        let last = UserDefaults.standard.string(forKey: key)

        var pool = affirmations
        if let last { pool.removeAll { $0.id == last } }

        let pick = pool.randomElement() ?? affirmations.randomElement()
        if let pick { UserDefaults.standard.set(pick.id, forKey: key) }
        return pick
    }
}

// MARK: - Routine Completion

extension AppDataModel {

    func toggleStep(stepID: String, date: Date = Date()) {
        guard isRoutineCompletionEditable(date: date) else { return }
        let key     = dateKey(date)
        let current = routineCompletion[key]?[stepID] ?? false
        if routineCompletion[key] == nil { routineCompletion[key] = [:] }
        routineCompletion[key]?[stepID] = !current
        persistRoutineCompletion()
    }

    func setStepDone(stepID: String, isDone: Bool, date: Date = Date()) {
        guard isRoutineCompletionEditable(date: date) else { return }
        let key = dateKey(date)
        if routineCompletion[key] == nil { routineCompletion[key] = [:] }
        routineCompletion[key]?[stepID] = isDone
        persistRoutineCompletion()
    }

    func isRoutineCompletionEditable(date: Date = Date(), now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let lockDate = calendar.date(byAdding: .day, value: 2, to: dayStart) else {
            return false
        }
        return now < lockDate
    }

    func isStepDone(stepID: String, date: Date = Date()) -> Bool {
        routineCompletion[dateKey(date)]?[stepID] ?? false
    }

    func completedStepIDs(date: Date = Date()) -> Set<String> {
        let completions = routineCompletion[dateKey(date)] ?? [:]
        return Set(completions.compactMap { $0.value ? $0.key : nil })
    }

    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func loadRoutineCompletion() -> [String: [String: Bool]] {
        guard let data = try? Data(contentsOf: routineCompletionURL) else { return [:] }
        return (try? JSONDecoder().decode([String: [String: Bool]].self, from: data)) ?? [:]
    }

    private func persistRoutineCompletion() {
        guard let data = try? JSONEncoder().encode(routineCompletion) else { return }
        try? data.write(to: routineCompletionURL)
        remoteStore.saveRoutineCompletion(routineCompletion)
    }

    private var routineCompletionURL: URL {
        documentsDirectory.appendingPathComponent("routine_completion.json")
    }
}

// MARK: - AI Routine

extension AppDataModel {

    func saveAIRoutine(_ output: AIRoutineOutput, reason: String? = nil) {
        let previousRoutine = aiRoutine ?? loadAIRoutineFromDisk()
        let hadRoutine = previousRoutine != nil
        guard let data = try? JSONEncoder().encode(output) else { return }
        try? data.write(to: aiRoutineURL)
        aiRoutine = output
        remoteStore.saveRoutine(output, reason: reason)

        let stepCount = output.morning.count + output.evening.count
        recordRoutineHistory(
            title: hadRoutine ? "Routine Updated" : "Routine Created",
            summary: "\(output.morning.count) morning and \(output.evening.count) evening steps",
            detail: reason ?? "Personalized routine saved with \(stepCount) total steps.",
            previousRoutine: previousRoutine,
            newRoutine: output
        )
    }

    func saveLastFaceScanResult(_ result: FaceScanResult) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        try? data.write(to: lastFaceScanURL)
        lastFaceScanResult = result
        remoteStore.saveFaceScanResult(result)
    }

    func loadTodayRoutineFromFirestore() async -> AIRoutineOutput? {
        guard let routine = try? await remoteStore.loadTodayRoutine() else { return nil }
        guard let data = try? JSONEncoder().encode(routine) else {
            aiRoutine = routine
            return routine
        }
        try? data.write(to: aiRoutineURL)
        aiRoutine = routine
        return routine
    }

    func onboardingDataFromProfile() -> OnboardingData? {
        guard let profile = userProfile else { return nil }
        return OnboardingData(
            birthYear: profile.birthYear,
            tZone: profile.tZone,
            uZone: profile.uZone,
            cZone: profile.cZone,
            sensitivity: profile.sensitivity,
            goals: profile.goals,
            uvExposure: profile.uvExposure
        )
    }

    func clearAIRoutine() {
        try? FileManager.default.removeItem(at: aiRoutineURL)
        aiRoutine = nil
        recordRoutineHistory(
            title: "Routine Cleared",
            summary: "Active AI routine was removed",
            detail: nil
        )
    }

    private func loadAIRoutineFromDisk() -> AIRoutineOutput? {
        guard let data = try? Data(contentsOf: aiRoutineURL) else { return nil }
        return try? JSONDecoder().decode(AIRoutineOutput.self, from: data)
    }

    private func loadLastFaceScanResult() -> FaceScanResult? {
        guard let data = try? Data(contentsOf: lastFaceScanURL) else { return nil }
        return try? JSONDecoder().decode(FaceScanResult.self, from: data)
    }

    private var aiRoutineURL: URL {
        documentsDirectory.appendingPathComponent("ai_routine.json")
    }

    private var lastFaceScanURL: URL {
        documentsDirectory.appendingPathComponent("last_face_scan.json")
    }
}

// MARK: - Saved Routines

extension AppDataModel {

    func saveRoutine(named name: String, from output: AIRoutineOutput) {
        savedRoutines.append(SavedRoutine(name: name, from: output))
        persistSavedRoutines()
        remoteStore.saveRoutine(output, reason: "Saved as \(name)")
    }

    func deleteSavedRoutine(id: String) {
        savedRoutines.removeAll { $0.id == id }
        persistSavedRoutines()
    }

    private func persistSavedRoutines() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(savedRoutines) else { return }
        try? data.write(to: savedRoutinesURL)
    }

    private func loadSavedRoutines() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard
            let data     = try? Data(contentsOf: savedRoutinesURL),
            let routines = try? decoder.decode([SavedRoutine].self, from: data)
        else { return }
        savedRoutines = routines
    }

    private var savedRoutinesURL: URL {
        documentsDirectory.appendingPathComponent("saved_routines.json")
    }
}

// MARK: - Routine History

extension AppDataModel {

    func recordRoutineHistory(
        title: String,
        summary: String,
        detail: String? = nil,
        previousRoutine: AIRoutineOutput? = nil,
        newRoutine: AIRoutineOutput? = nil
    ) {
        routineHistory.insert(
            RoutineHistoryEntry(
                title: title,
                summary: summary,
                detail: detail,
                previousRoutine: previousRoutine,
                newRoutine: newRoutine
            ),
            at: 0
        )
        persistRoutineHistory()
    }

    private func persistRoutineHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(routineHistory) else { return }
        try? data.write(to: routineHistoryURL)
    }

    private func loadRoutineHistory() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard
            let data = try? Data(contentsOf: routineHistoryURL),
            let history = try? decoder.decode([RoutineHistoryEntry].self, from: data)
        else { return }
        routineHistory = history.sorted { $0.changedAt > $1.changedAt }
    }

    private var routineHistoryURL: URL {
        documentsDirectory.appendingPathComponent("routine_history.json")
    }

    private func seedRoutineHistoryIfNeeded() {
        guard routineHistory.isEmpty, let aiRoutine else { return }
        let stepCount = aiRoutine.morning.count + aiRoutine.evening.count
        routineHistory = [
            RoutineHistoryEntry(
                title: "Current Routine",
                summary: "\(aiRoutine.morning.count) morning and \(aiRoutine.evening.count) evening steps",
                detail: "This routine was already active before history tracking was added. \(stepCount) total steps are available.",
                newRoutine: aiRoutine
            )
        ]
        persistRoutineHistory()
    }
}

// MARK: - Journal Entries

extension AppDataModel {

    func clearUserDataForLogout() {
        UserProfile.clear()
        userProfile = nil
        journalEntries = []
        savedRoutines = []
        routineHistory = []
        aiRoutine = nil
        routineCompletion = [:]

        [
            journalEntriesURL,
            savedRoutinesURL,
            routineHistoryURL,
            aiRoutineURL
        ].forEach {
            try? FileManager.default.removeItem(at: $0)
        }
    }

    func addJournalEntry(_ entry: JournalEntry) {
        journalEntries.insert(entry, at: 0)
        persistJournalEntries()
        remoteStore.saveJournalEntry(entry)
    }

    func deleteJournalEntry(id: String) {
        journalEntries.removeAll { $0.id == id }
        persistJournalEntries()
        remoteStore.deleteJournalEntry(id: id)
    }

    func journalEntries(for date: Date) -> [JournalEntry] {
        journalEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func persistJournalEntries() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(journalEntries) else { return }
        try? data.write(to: journalEntriesURL)
    }

    private func loadJournalEntries() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard
            let data    = try? Data(contentsOf: journalEntriesURL),
            let entries = try? decoder.decode([JournalEntry].self, from: data)
        else { return }
        journalEntries = entries
    }

    private var journalEntriesURL: URL {
        documentsDirectory.appendingPathComponent("journal_entries.json")
    }
}

// MARK: - Helpers

private extension AppDataModel {

    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
