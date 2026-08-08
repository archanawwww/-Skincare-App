import Foundation
import UIKit

final class InsightStore {
    static let shared = InsightStore()

    private let persistedFileName = "insights_history_v1.json"

    func allEntries() -> [InsightEntry] {
        (bundledEntries() + persistedEntries())
            .sorted { ($0.dateValue ?? .distantPast) < ($1.dateValue ?? .distantPast) }
    }

    func entries(on date: Date) -> [InsightEntry] {
        let calendar = Calendar.current
        let orderedEntries = bundledEntries() + persistedEntries()
        return orderedEntries.enumerated().filter { _, entry in
            guard let value = entry.dateValue else { return false }
            return calendar.isDate(value, inSameDayAs: date)
        }.sorted { lhs, rhs in
            let leftDate = lhs.element.dateValue ?? .distantPast
            let rightDate = rhs.element.dateValue ?? .distantPast
            if leftDate == rightDate { return lhs.offset > rhs.offset }
            return leftDate > rightDate
        }.map(\.element)
    }

    func hasFaceScan(on date: Date) -> Bool {
        entries(on: date).contains { $0.hasFaceScan }
    }

    func hasWeeklyInput(on date: Date) -> Bool {
        entries(on: date).contains { $0.hasWeeklyInput }
    }

    func saveFaceScan(image: UIImage?, result: FaceScanResult) {
        let now = Date()
        let dateString = InsightDateFormatter.shared.string(from: now)
        let localImageName = image.flatMap(saveImage)
        let features = result.concerns.map {
            InsightDetectedFeature(
                issue: $0.name,
                location: $0.area,
                severity: $0.severity,
                coordinates: nil
            )
        }
        let entry = InsightEntry(
            date: dateString,
            scanType: .normal,
            scanImageURL: nil,
            localImageName: localImageName,
            aiDetection: InsightDetection(overallScore: nil, detectedFeatures: features),
            analysisReport: InsightAnalysisReport(
                summary: "Face scan completed.",
                comparativeInsights: features.map {
                    InsightComparativeInsight(
                        attribute: $0.issue,
                        location: $0.location,
                        changeType: .neutral,
                        message: "\($0.issue) detected around \($0.location.lowercased())."
                    )
                }
            ),
            weeklyInputData: nil
        )

        var history = persistedEntries()
        removeEntries(from: &history, on: now, matching: { $0.hasFaceScan })
        history.append(entry)
        persist(history)
    }
    func saveWeeklyInput(_ weeklyInput: InsightWeeklyInput) {

        let now = Date()

        let entry = InsightEntry(
            date: InsightDateFormatter.shared.string(from: now),
            scanType: .weeklyInput,
            scanImageURL: nil,
            localImageName: nil,
            aiDetection: .empty,
            analysisReport: nil,
            weeklyInputData: weeklyInput
        )

        var history = persistedEntries()
        removeEntries(from: &history, on: now, matching: { $0.hasWeeklyInput })
        history.append(entry)
        persist(history)
    }

    func image(for entry: InsightEntry) -> UIImage? {
        if let localImageName = entry.localImageName {
            let url = imagesDirectory.appendingPathComponent(localImageName)
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return image
            }
        }
        return UIImage(named: "FemaleFace")
    }

    private func bundledEntries() -> [InsightEntry] {
        guard
            let url = Bundle.main.url(forResource: "Insight", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let root = try? JSONDecoder().decode(InsightRoot.self, from: data)
        else { return [] }
        return root.insightsHistory
    }

    private func persistedEntries() -> [InsightEntry] {
        guard
            let data = try? Data(contentsOf: persistedURL),
            let entries = try? JSONDecoder().decode([InsightEntry].self, from: data)
        else { return [] }
        return entries
    }

    private func persist(_ entries: [InsightEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: persistedURL)
    }

    private func removeEntries(from entries: inout [InsightEntry],
                               on date: Date,
                               matching predicate: (InsightEntry) -> Bool) {
        let calendar = Calendar.current
        let removedImageNames = entries.compactMap { entry -> String? in
            guard
                predicate(entry),
                let value = entry.dateValue,
                calendar.isDate(value, inSameDayAs: date)
            else { return nil }
            return entry.localImageName
        }

        entries.removeAll { entry in
            guard
                predicate(entry),
                let value = entry.dateValue
            else { return false }
            return calendar.isDate(value, inSameDayAs: date)
        }

        for imageName in removedImageNames {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(imageName))
        }
    }

    private func saveImage(_ image: UIImage) -> String? {
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let fileName = "face_scan_\(UUID().uuidString).jpg"
        let url = imagesDirectory.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try data.write(to: url)
            return fileName
        } catch {
            return nil
        }
    }

    private var persistedURL: URL {
        documentsDirectory.appendingPathComponent(persistedFileName)
    }

    private var imagesDirectory: URL {
        documentsDirectory.appendingPathComponent("InsightFaceScans", isDirectory: true)
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
