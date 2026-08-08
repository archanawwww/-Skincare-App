import Foundation

// MARK: - Enums

enum SkinType: String, CaseIterable, Codable {
    case oily, dry, normal, combination
}

enum SensitivityLevel: String, CaseIterable, Codable {
    case hardlyEver, sometimes, often, veryEasily
}

enum UVExposureLevel: String, CaseIterable, Codable {
    case rarely, moderate, high, veryHigh
}

enum SkinGoal: String, CaseIterable, Codable {
    case maintainSkin
    case hydration
    case oilControl
    case glow
    case toneImprove
    case antiAging
    case poreMinimize
    case routineOnly
}

enum TimeOfDay: String, Codable {
    case morning, evening
}

enum StepType: String, Codable {
    case cleanser, toner, serum, moisturizer, sunscreen, treatment, repair

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self).lowercased()
        self = StepType(rawValue: raw) ?? .treatment
    }
}

// MARK: - Root JSON

struct SkinCareRoot: Codable {

    let ingredients: [Ingredient]
    let users: [User]
    let profiles: [Profile]
    let routines: [Routine]
    let journals: [JournalEntry]
    let weeklyProgress: [WeeklyProgress]
    let dailyTip: DailyTip
    let skinInsights: [SkinInsight]
    let affirmations: [Affirmation]

    enum CodingKeys: String, CodingKey {

        case ingredients
        case users
        case profiles
        case routines
        case journals
        case weeklyProgress = "weekly_progress"
        case dailyTip = "daily_tip"
        case skinInsights = "skin_insights"
        case affirmations
    }
}

// MARK: - User

struct User: Codable {

    let id: String
    let username: String
    let email: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {

        case id
        case username
        case email
        case createdAt = "created_at"
    }
}

// MARK: - Profile

struct Profile: Codable {

    let id: String
    let userID: String
    let tZoneType: SkinType
    let uZoneType: SkinType
    let cZoneType: SkinType
    let sensitivityLevel: SensitivityLevel
    let uvExposureLevel: UVExposureLevel
    let goals: [SkinGoal]

    enum CodingKeys: String, CodingKey {

        case id
        case userID = "user_id"
        case tZoneType = "t_zone_type"
        case uZoneType = "u_zone_type"
        case cZoneType = "c_zone_type"
        case sensitivityLevel = "sensitivity_level"
        case uvExposureLevel = "uv_exposure_level"
        case goals
    }
}

// MARK: - Ingredient (Used by BOTH Home + Routine)

struct Ingredient: Codable {

    let id: String
    let name: String

    // Home screen
    let aliases: [String]?
    let uses: [String]?
    let evidenceScore: Double?
    let safeForSensitive: Bool?
    let conflictingWith: [String]

    // Detail screen
    let scientificName: String?
    let shortDescription: String?
    let whatDoesItDo: [String]?
    let avoidWith: [String]?

    // NEW (missing fields)
    let tags: [String]?
    let bestFor: [String]?
    let whenToUse: String?
    let minConcentration: Double?
    let maxConcentration: Double?
    let combinesWith: [String]?

    enum CodingKeys: String, CodingKey {

        case id
        case name
        case aliases
        case uses

        case evidenceScore = "evidence_score"
        case safeForSensitive = "safe_for_sensitive"
        case conflictingWith = "conflicting_with"

        case scientificName
        case shortDescription
        case whatDoesItDo
        case avoidWith

        // NEW
        case tags
        case bestFor
        case whenToUse
        case minConcentration
        case maxConcentration
        case combinesWith
    }
}

// MARK: - Routine

struct Routine: Codable {

    let id: String
    let userID: String
    let isActive: Bool
    let steps: [RoutineStep]

    enum CodingKeys: String, CodingKey {

        case id
        case userID = "user_id"
        case isActive
        case steps
    }
}

// MARK: - Routine Step

struct RoutineStep: Codable {

    let id: String
    let stepOrder: Int
    let stepTitle: String
    let type: StepType
    let productDescription: String
    let ingredientIDs: [String]
    let timeOfDay: TimeOfDay
    let instructionText: String

    enum CodingKeys: String, CodingKey {

        case id
        case stepOrder = "step_order"
        case stepTitle = "step_title"
        case type
        case productDescription = "product_desc"
        case ingredientIDs = "ingredient_ids"
        case timeOfDay = "time_of_day"
        case instructionText = "instruction_text"
    }
}

// MARK: - Journal Entry

struct JournalEntry: Codable {

    let id: String
    let userID: String
    var title: String
    var note: String
    var flareUps: [String]
    let date: Date
    var photoFileNames: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title
        case note
        case flareUps
        case date
        case photoFileNames
    }

    init(id: String, userID: String, title: String = "", note: String, flareUps: [String], date: Date = Date(), photoFileNames: [String] = []) {
        self.id = id
        self.userID = userID
        self.title = title
        self.note = note
        self.flareUps = flareUps
        self.date = date
        self.photoFileNames = photoFileNames
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userID = try c.decode(String.self, forKey: .userID)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        note = try c.decode(String.self, forKey: .note)
        flareUps = try c.decode([String].self, forKey: .flareUps)
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
        photoFileNames = (try? c.decode([String].self, forKey: .photoFileNames)) ?? []
    }
}

// MARK: - Skin Report Entry

struct SkinLogEntry: Codable {
    let id: String
    let date: Date
    let isFlareUp: Bool
    let flareUps: [String]    // skin concerns (Acne, Redness, etc.)
    let note: String
    let title: String
    let photoFileNames: [String]

    init(id: String = String(Date().timeIntervalSince1970),
         date: Date = Date(),
         isFlareUp: Bool,
         flareUps: [String],
         note: String,
         title: String = "",
         photoFileNames: [String] = []) {
        self.id = id
        self.date = date
        self.isFlareUp = isFlareUp
        self.flareUps = flareUps
        self.note = note
        self.title = title
        self.photoFileNames = photoFileNames
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
        isFlareUp = (try? c.decode(Bool.self, forKey: .isFlareUp)) ?? false
        flareUps = (try? c.decode([String].self, forKey: .flareUps)) ?? []
        note = (try? c.decode(String.self, forKey: .note)) ?? ""
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        photoFileNames = (try? c.decode([String].self, forKey: .photoFileNames)) ?? []
    }
}

// MARK: - Weekly Progress

struct WeeklyProgress: Codable {

    let id: String
    let userID: String
    let weekStart: String
    let days: [DayProgress]

    enum CodingKeys: String, CodingKey {

        case id
        case userID = "user_id"
        case weekStart = "week_start"
        case days
    }
}

struct DayProgress: Codable {

    let day: String
    let progress: Double
}

// MARK: - Daily Tip

struct DailyTip: Codable {

    let tipTitle: String
    let tipDesc: String
    let sunTitle: String
    let sunDesc: String

    enum CodingKeys: String, CodingKey {

        case tipTitle = "tip_title"
        case tipDesc = "tip_desc"
        case sunTitle = "sun_title"
        case sunDesc = "sun_desc"
    }
}

// MARK: - Skin Insight

struct SkinInsight: Codable {

    let id: String
    let icon: String
    let title: String
    let percent: Int
}

// MARK: - Affirmation

struct Affirmation: Codable {

    let id: String
    let text: String
}
