import Foundation
import UIKit

struct InsightRoot: Codable {
    let userID: String
    var insightsHistory: [InsightEntry]
    let metaData: InsightMetaData?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case insightsHistory = "insights_history"
        case metaData = "meta_data"
    }
}

struct InsightEntry: Codable {
    let id: String
    let date: String
    let isToday: Bool?
    let scanType: InsightScanType
    let scanImageURL: String?
    let localImageName: String?
    let aiDetection: InsightDetection
    let analysisReport: InsightAnalysisReport?
    let weeklyInputData: InsightWeeklyInput?

    var dateValue: Date? {
        InsightDateFormatter.shared.date(from: date)
    }

    var hasWeeklyInput: Bool {
        weeklyInputData != nil || scanType == .weeklyInput
    }

    var hasFaceScan: Bool {
        guard scanType == .normal else { return false }
        return !aiDetection.detectedFeatures.isEmpty ||
        !(analysisReport?.comparativeInsights ?? []).isEmpty ||
        scanImageURL != nil ||
        localImageName != nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case isToday = "is_today"
        case scanType = "scan_type"
        case scanImageURL = "scan_image_url"
        case localImageName = "local_image_name"
        case aiDetection = "ai_detection"
        case analysisReport = "analysis_report"
        case weeklyInputData = "weekly_input_data"
    }

    init(id: String = UUID().uuidString,
         date: String,
         isToday: Bool? = nil,
         scanType: InsightScanType,
         scanImageURL: String?,
         localImageName: String? = nil,
         aiDetection: InsightDetection,
         analysisReport: InsightAnalysisReport? = nil,
         weeklyInputData: InsightWeeklyInput?) {
        self.id = id
        self.date = date
        self.isToday = isToday
        self.scanType = scanType
        self.scanImageURL = scanImageURL
        self.localImageName = localImageName
        self.aiDetection = aiDetection
        self.analysisReport = analysisReport
        self.weeklyInputData = weeklyInputData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        date = try container.decode(String.self, forKey: .date)
        isToday = try container.decodeIfPresent(Bool.self, forKey: .isToday)
        scanType = try container.decode(InsightScanType.self, forKey: .scanType)
        scanImageURL = try container.decodeIfPresent(String.self, forKey: .scanImageURL)
        localImageName = try container.decodeIfPresent(String.self, forKey: .localImageName)
        aiDetection = try container.decodeIfPresent(InsightDetection.self, forKey: .aiDetection) ?? .empty
        analysisReport = try container.decodeIfPresent(InsightAnalysisReport.self, forKey: .analysisReport)
        weeklyInputData = try container.decodeIfPresent(InsightWeeklyInput.self, forKey: .weeklyInputData)
    }
}

enum InsightScanType: String, Codable {
    case normal
    case weeklyInput = "weekly_input"
}

struct InsightDetection: Codable {
    let overallScore: Int?
    let detectedFeatures: [InsightDetectedFeature]

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case detectedFeatures = "detected_features"
    }

    static let empty = InsightDetection(overallScore: nil, detectedFeatures: [])
}

struct InsightDetectedFeature: Codable {
    let issue: String
    let location: String
    let severity: String
    let coordinates: InsightCoordinates?
}

struct InsightAnalysisReport: Codable {
    let summary: String?
    let comparativeInsights: [InsightComparativeInsight]

    enum CodingKeys: String, CodingKey {
        case summary
        case comparativeInsights = "comparative_insights"
    }
}

struct InsightComparativeInsight: Codable {
    let attribute: String
    let location: String?
    let changeType: InsightChangeType
    let message: String

    enum CodingKeys: String, CodingKey {
        case attribute
        case location
        case changeType = "change_type"
        case message
    }
}

enum InsightChangeType: String, Codable {
    case positive
    case negative
    case neutral
}

struct InsightCoordinates: Codable {
    let x: CGFloat
    let y: CGFloat
}

struct InsightWeeklyInput: Codable {
    let insightTitle: String?
    let skinFeel: String?
    let concerns: [String]
    let lifestyleFactors: InsightLifestyleFactors
    let productChanges: [InsightProductChange]
    let correlationLogic: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case insightTitle = "insight_title"
        case skinFeel = "skin_feel"
        case concerns
        case lifestyleFactors = "lifestyle_factors"
        case productChanges = "product_changes"
        case correlationLogic = "correlation_logic"
        case notes
    }
    init(
        insightTitle: String?,
        skinFeel: String?,
        concerns: [String],
        lifestyleFactors: InsightLifestyleFactors,
        productChanges: [InsightProductChange],
        correlationLogic: String?,
        notes: String?
    ) {
        self.insightTitle = insightTitle
        self.skinFeel = skinFeel
        self.concerns = concerns
        self.lifestyleFactors = lifestyleFactors
        self.productChanges = productChanges
        self.correlationLogic = correlationLogic
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        insightTitle = try container.decodeIfPresent(String.self, forKey: .insightTitle)
        skinFeel = try container.decodeIfPresent(String.self, forKey: .skinFeel)
        concerns = try container.decodeIfPresent([String].self, forKey: .concerns) ?? []
        lifestyleFactors = try container.decodeIfPresent(InsightLifestyleFactors.self, forKey: .lifestyleFactors) ?? .empty
        productChanges = try container.decodeIfPresent([InsightProductChange].self, forKey: .productChanges) ?? []
        correlationLogic = try container.decodeIfPresent(String.self, forKey: .correlationLogic)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

struct InsightLifestyleFactors: Codable {
    let sleepQuality: Int?
    let stressLevel: Double?
    let waterIntakeAvg: Int?
    let waterGoal: Int?
    init(
        sleepQuality: Int?,
        stressLevel: Double?,
        waterIntakeAvg: Int?,
        waterGoal: Int?
    ) {
        self.sleepQuality = sleepQuality
        self.stressLevel = stressLevel
        self.waterIntakeAvg = waterIntakeAvg
        self.waterGoal = waterGoal
    }

    enum CodingKeys: String, CodingKey {
        case sleepQuality = "sleep_quality"
        case stressLevel = "stress_level"
        case waterIntakeAvg = "water_intake_avg"
        case waterGoal = "water_goal"
    }

    static let empty = InsightLifestyleFactors(sleepQuality: nil, stressLevel: nil, waterIntakeAvg: nil, waterGoal: nil)
}

struct InsightProductChange: Codable {
    let action: String
    let productName: String

    enum CodingKeys: String, CodingKey {
        case action
        case productName = "product_name"
    }
}

struct InsightMetaData: Codable {
    let emptyStateMessage: String?

    enum CodingKeys: String, CodingKey {
        case emptyStateMessage = "empty_state_message"
    }
}

enum InsightDateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
