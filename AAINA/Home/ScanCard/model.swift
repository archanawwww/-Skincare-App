//
//  model.swift
//  ScanCard
//

import Foundation

// MARK: - Scan Verdict

enum ScanVerdict {
    case recommended, useWithCaution, notRecommended, notRelevant

    var label: String {
        switch self {
        case .recommended:    return "Recommended"
        case .useWithCaution: return "Use with Caution"
        case .notRecommended: return "Not Recommended"
        case .notRelevant:    return "Not a Skincare Product"
        }
    }

    var systemIcon: String {
        switch self {
        case .recommended:    return "checkmark.circle.fill"
        case .useWithCaution: return "exclamationmark.triangle.fill"
        case .notRecommended: return "xmark.circle.fill"
        case .notRelevant:    return "questionmark.circle.fill"
        }
    }
}

// MARK: - Ingredient Category

enum IngredientCategory {
    case goodForYou, useWithCaution, avoid
}

struct CategorisedIngredient {
    let name: String
    let explanation: String
    let category: IngredientCategory
}

// MARK: - Scan Analysis Result

struct ScanAnalysisResult {
    let verdict: ScanVerdict
    let verdictReason: String
    let goodForYou: [CategorisedIngredient]
    let useWithCaution: [CategorisedIngredient]
    let avoid: [CategorisedIngredient]
    let detectedIngredients: [String]       // all recognised names (for display)

    // Backward-compat shims
    var isRecommended: Bool { verdict == .recommended }
    var title: String { verdict.label }
    var detail: String { verdictReason }
    var matchedIngredients: [String] { goodForYou.map(\.name) }
    var conflicts: [String] { avoid.map { "\($0.name): \($0.explanation)" } }
}

// MARK: - Routine Manager

class RoutineManager {
    private let dataModel = DataModel()

    private let weakIngredientTokens: Set<String> = [
        "acid", "extract", "water", "aqua", "oil", "root", "leaf", "fruit",
        "seed", "sodium", "potassium", "tocopherol", "alcohol"
    ]

    private let routine: [String: [String]] = [
        "Cleanser":    ["glycerin", "niacinamide"],
        "Serum":       ["vitamin c", "hyaluronic acid"],
        "Moisturizer": ["ceramide", "peptides"],
        "Sunscreen":   ["zinc oxide", "avobenzone"]
    ]

    private let conflicts: [[String]] = [
        ["retinol", "aha"],
        ["retinol", "glycolic acid"],
        ["retinol", "lactic acid"],
        ["retinol", "salicylic acid"],
        ["benzoyl peroxide", "retinol"],
        ["vitamin c", "benzoyl peroxide"],
        ["aha", "vitamin c"]
    ]

    // MARK: - Ingredient alias database (expanded)

    private let ingredientAliases: [String: [String]] = [
        // ── Actives ──────────────────────────────────────────────
        "aha":              ["aha", "alpha hydroxy acid", "glycolic acid",
                             "lactic acid", "mandelic acid", "tartaric acid"],
        "niacinamide":      ["niacinamide", "vitamin b3", "nicotinamide"],
        "retinol":          ["retinol", "retinal", "retinaldehyde",
                             "retinyl palmitate", "retinoid", "retinoic acid"],
        "vitamin c":        ["vitamin c", "ascorbic acid", "ethyl ascorbic acid",
                             "3-o-ethyl ascorbic acid", "ascorbyl glucoside",
                             "sodium ascorbyl phosphate", "magnesium ascorbyl phosphate",
                             "ascorbyl tetraisopalmitate"],
        "salicylic acid":   ["salicylic acid", "bha", "beta hydroxy acid",
                             "willow bark extract"],
        "glycolic acid":    ["glycolic acid"],
        "lactic acid":      ["lactic acid"],
        "mandelic acid":    ["mandelic acid"],
        "azelaic acid":     ["azelaic acid"],
        "tranexamic acid":  ["tranexamic acid"],
        "ferulic acid":     ["ferulic acid"],
        "kojic acid":       ["kojic acid", "kojic dipalmitate"],
        "alpha arbutin":    ["alpha arbutin", "arbutin", "beta-arbutin"],
        "bakuchiol":        ["bakuchiol"],
        "adenosine":        ["adenosine"],

        // ── Humectants / hydrators ────────────────────────────────
        "hyaluronic acid":  ["hyaluronic acid", "sodium hyaluronate",
                             "hydrolyzed hyaluronic acid", "sodium hyaluronyl acrylate copolymer"],
        "glycerin":         ["glycerin", "glycerine", "glycerol"],
        "panthenol":        ["panthenol", "pro-vitamin b5", "vitamin b5",
                             "d-panthenol", "dl-panthenol", "dexpanthenol"],
        "sodium pca":       ["sodium pca", "sodium pyrrolidone carboxylate"],
        "butylene glycol":  ["butylene glycol", "1,3-butylene glycol"],
        "propylene glycol": ["propylene glycol"],
        "propanediol":      ["propanediol", "1,3-propanediol"],

        // ── Barrier / emollient ───────────────────────────────────
        "ceramide":         ["ceramide", "ceramide np", "ceramide ap",
                             "ceramide eop", "ceramide ng", "ceramide ag",
                             "phytosphingosine", "sphingolipid"],
        "squalane":         ["squalane", "squalene", "olive-derived squalane"],
        "peptides":         ["peptide", "peptides", "palmitoyl tripeptide",
                             "palmitoyl tetrapeptide", "palmitoyl oligopeptide",
                             "acetyl hexapeptide", "copper peptide", "sh-oligopeptide"],
        "allantoin":        ["allantoin"],
        "tocopherol":       ["tocopherol", "tocopheryl acetate", "vitamin e",
                             "dl-alpha-tocopherol", "mixed tocopherols"],
        "centella":         ["centella", "centella asiatica", "cica",
                             "madecassoside", "asiaticoside", "asiatic acid",
                             "centella extract", "tiger grass"],
        "aloe vera":        ["aloe vera", "aloe barbadensis", "aloe barbadensis leaf juice",
                             "aloe barbadensis gel", "aloe leaf juice"],
        "green tea":        ["green tea extract", "camellia sinensis",
                             "camellia sinensis leaf extract", "epigallocatechin",
                             "egcg"],
        "licorice root":    ["licorice root extract", "glycyrrhiza glabra",
                             "glycyrrhiza uralensis", "licorice extract",
                             "dipotassium glycyrrhizate"],

        // ── Sunscreen filters ─────────────────────────────────────
        "zinc oxide":       ["zinc oxide"],
        "titanium dioxide": ["titanium dioxide"],
        "avobenzone":       ["avobenzone", "butyl methoxydibenzoylmethane"],
        "octinoxate":       ["octinoxate", "octyl methoxycinnamate",
                             "ethylhexyl methoxycinnamate"],
        "octocrylene":      ["octocrylene"],
        "oxybenzone":       ["oxybenzone", "benzophenone-3"],

        // ── Acne fighters ─────────────────────────────────────────
        "benzoyl peroxide": ["benzoyl peroxide"],
        "sulfur":           ["sulfur", "colloidal sulfur"],

        // ── Common formulation ingredients (for detection only) ───
        "dimethicone":      ["dimethicone", "cyclomethicone",
                             "cyclopentasiloxane", "cyclohexasiloxane",
                             "dimethiconol"],
        "cetearyl alcohol": ["cetearyl alcohol"],
        "cetyl alcohol":    ["cetyl alcohol"],
        "phenoxyethanol":   ["phenoxyethanol"],
        "carbomer":         ["carbomer", "carbopol", "polyacrylic acid"],
        "xanthan gum":      ["xanthan gum"],
        "glyceryl stearate":["glyceryl stearate", "glyceryl stearate se"],
        "caprylic capric triglyceride": ["caprylic capric triglyceride",
                             "caprylic/capric triglyceride",
                             "medium chain triglycerides"],
        "aqua":             ["aqua", "water", "eau", "purified water",
                             "deionized water", "distilled water"]
    ]

    // MARK: - Personalisation databases

    private let ingredientExplanations: [String: String] = [
        "niacinamide":       "Brightens, controls oil, and minimises pores",
        "hyaluronic acid":   "Deep hydration that suits all skin types",
        "vitamin c":         "Fades dark spots and boosts natural glow",
        "retinol":           "Reduces fine lines — start slowly and patch-test first",
        "salicylic acid":    "Clears breakouts by unclogging pores",
        "glycolic acid":     "Exfoliates dead skin — always follow with SPF",
        "lactic acid":       "Gentle exfoliation, great for sensitive skin",
        "ceramide":          "Rebuilds the skin barrier and locks in moisture",
        "glycerin":          "Lightweight moisture suited to all skin types",
        "benzoyl peroxide":  "Kills acne bacteria — can be drying at first",
        "zinc oxide":        "Mineral SPF, very gentle on sensitive skin",
        "titanium dioxide":  "Mineral SPF, good for sensitive skin",
        "avobenzone":        "Chemical UV filter — works best with SPF boosters",
        "peptides":          "Boosts collagen production for firmer skin",
        "aha":               "Exfoliates dead skin — always follow with SPF",
        "mandelic acid":     "Gentle exfoliant, ideal for sensitive or darker skin tones",
        "azelaic acid":      "Calms redness and fades pigmentation spots",
        "squalane":          "Feather-light oil that balances any skin type",
        "centella":          "Calms redness and supports the skin's natural healing",
        "tranexamic acid":   "Targets dark spots and uneven skin tone",
        "panthenol":         "Soothes and helps the skin hold moisture",
        "allantoin":         "Calms irritation and speeds skin recovery",
        "tocopherol":        "Antioxidant that protects and softens skin",
        "alpha arbutin":     "Brightens dark spots without irritation",
        "bakuchiol":         "Retinol-like results, safe for sensitive skin",
        "ferulic acid":      "Boosts Vitamin C effectiveness and fights free radicals",
        "kojic acid":        "Brightens dark spots — avoid if very sensitive",
        "aloe vera":         "Soothes, hydrates, and calms inflammation",
        "green tea":         "Antioxidant that reduces redness and UV damage",
        "licorice root":     "Brightens skin and reduces redness",
        "adenosine":         "Smooths fine lines and firms the skin"
    ]

    private let skinTypeGoodIngredients: [SkinType: Set<String>] = [
        .oily:        ["niacinamide", "salicylic acid", "hyaluronic acid", "aha",
                       "glycolic acid", "lactic acid", "zinc oxide", "azelaic acid",
                       "green tea", "panthenol"],
        .dry:         ["ceramide", "hyaluronic acid", "glycerin", "squalane",
                       "peptides", "lactic acid", "panthenol", "allantoin",
                       "tocopherol", "aloe vera"],
        .combination: ["niacinamide", "hyaluronic acid", "glycerin", "azelaic acid",
                       "squalane", "panthenol"],
        .normal:      ["hyaluronic acid", "niacinamide", "peptides", "vitamin c",
                       "allantoin", "green tea"]
    ]

    private let concernGoodIngredients: [SkinConcern: Set<String>] = [
        .acne:         ["salicylic acid", "niacinamide", "benzoyl peroxide",
                        "aha", "azelaic acid", "zinc oxide", "green tea"],
        .darkSpots:    ["vitamin c", "niacinamide", "azelaic acid", "glycolic acid",
                        "tranexamic acid", "alpha arbutin", "kojic acid",
                        "licorice root"],
        .darkCircles:  ["vitamin c", "peptides", "niacinamide", "retinol",
                        "caffeine"],
        .foreheadBumps:["salicylic acid", "aha", "niacinamide"],
        .blackheads:   ["salicylic acid", "aha", "niacinamide"],
        .whiteheads:   ["salicylic acid", "retinol", "aha"],
        .redness:      ["azelaic acid", "niacinamide", "zinc oxide", "centella",
                        "allantoin", "aloe vera", "green tea", "licorice root"],
        .fineLines:    ["retinol", "peptides", "vitamin c", "aha",
                        "bakuchiol", "adenosine"],
        .pigmentation: ["vitamin c", "niacinamide", "azelaic acid", "glycolic acid",
                        "tranexamic acid", "alpha arbutin", "kojic acid"]
    ]

    private let cautionIngredientSet: Set<String> = [
        "retinol", "aha", "glycolic acid", "lactic acid", "mandelic acid",
        "salicylic acid", "benzoyl peroxide", "kojic acid"
    ]

    // Keywords that confirm this is a skincare/cosmetic label
    private let skincareMarkers: Set<String> = [
        "aqua", "glycerin", "glycerine", "glycerol", "phenoxyethanol",
        "dimethicone", "cyclopentasiloxane", "carbomer", "niacinamide",
        "hyaluronic", "sodium hyaluronate", "ceramide", "retinol", "retinyl",
        "tocopherol", "tocopheryl", "panthenol", "allantoin", "salicylic",
        "glycolic", "ascorbic", "butylene glycol", "propanediol",
        "caprylic", "cetearyl", "cetyl alcohol", "xanthan gum",
        "parfum", "fragrance", "inci", "zinc oxide", "titanium dioxide",
        "avobenzone", "disodium edta", "sodium pca"
    ]

    // MARK: - Lazy computed

    private lazy var mergedIngredientAliases: [String: [String]] = {
        var aliases = ingredientAliases
        for ingredient in AppDataModel.shared.allIngredients() {
            let key = normalizeIngredient(ingredient.name)
            var values = aliases[key] ?? [ingredient.name]
            values.append(ingredient.name)
            values.append(contentsOf: ingredient.aliases ?? [])
            aliases[key] = Array(Set(values.map(normalize))).sorted()
        }
        return aliases
    }()

    private lazy var allConflictPairs: [[String]] = {
        var pairs = conflicts
        for ingredient in AppDataModel.shared.allIngredients() {
            for conflict in ingredient.avoidWith ?? [] {
                pairs.append([ingredient.name, conflict])
            }
            for conflictingID in ingredient.conflictingWith {
                guard let ci = AppDataModel.shared.ingredient(forID: conflictingID) else { continue }
                pairs.append([ingredient.name, ci.name])
            }
        }
        return deduplicatedConflictPairs(from: pairs)
    }()

    // MARK: - Public API

    func getRoutineIngredients(for step: String) -> [String] {
        let fallback = routine[step] ?? []
        let stepKey  = step.lowercased()
        let aiIngredients = AppDataModel.shared.aiRoutineIngredients()
            .filter { $0.step == stepKey }.flatMap { $0.ingredients }
        let currentUserID = dataModel.currentUser().id
        let jsonIngredients = dataModel.routineStepsForHomeScreen(for: currentUserID)
            .filter { $0.type.rawValue == stepKey }
            .flatMap { dataModel.ingredientNames(for: $0) }
        return Array(Set((fallback + aiIngredients + jsonIngredients).map(normalizeIngredient))).sorted()
    }

    func getConflictingPairs() -> [[String]] { allConflictPairs }
    func currentRoutineContains(_ ingredient: String) -> Bool {
        currentRoutineIngredients().contains(normalizeIngredient(ingredient))
    }

    // Identify known ingredient keys from normalised OCR text
    func identifyIngredients(in text: String) -> [String] {
        let normalizedText = normalize(text)
        let textTokens     = Set(normalizedText.split(separator: " ").map(String.init))
        var detected       = Set<String>()

        // Method A: phrase presence in the full text
        for (ingredient, aliases) in mergedIngredientAliases {
            if aliases.contains(where: { containsPhrase($0, in: normalizedText) }) ||
               matchesIngredientTokens(ingredient: ingredient, aliases: aliases, textTokens: textTokens) {
                detected.insert(ingredient)
            }
        }

        // Method B: exact-match each comma-split token (catches OCR where commas have no spaces)
        let commaTokens = normalizedText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 3 && $0.count < 50 }

        for token in commaTokens {
            for (ingredient, aliases) in mergedIngredientAliases {
                guard !detected.contains(ingredient) else { continue }
                if aliases.contains(where: { normalize($0) == token }) {
                    detected.insert(ingredient)
                }
            }
        }

        return detected.sorted()
    }

    // Main analysis — rawText is the unprocessed OCR output used for relevance detection
    func analyze(scannedIngredients: [String], rawText: String = "", for step: String) -> ScanAnalysisResult {

        // ── Non-relevant product detection ────────────────────────
        let looksLikeSkincare = checkLooksLikeSkincare(rawText)
        if !looksLikeSkincare && scannedIngredients.isEmpty {
            return ScanAnalysisResult(
                verdict:             .notRelevant,
                verdictReason:       "This doesn't appear to be a skincare product. Point the camera at the full ingredient list on the back of the label.",
                goodForYou:          [],
                useWithCaution:      [],
                avoid:               [],
                detectedIngredients: []
            )
        }

        // ── No recognised ingredients (but it's skincare-like) ───
        if scannedIngredients.isEmpty {
            return ScanAnalysisResult(
                verdict:             .notRecommended,
                verdictReason:       "No key ingredients were recognised. Move closer to the list and ensure the text is in focus.",
                goodForYou:          [],
                useWithCaution:      [],
                avoid:               [],
                detectedIngredients: []
            )
        }

        let profile     = AppDataModel.shared.userProfile
        let skinType    = profile?.dominantSkinType ?? .normal
        let concerns    = profile?.concerns ?? []
        let isSensitive: Bool = {
            guard let s = profile?.sensitivity else { return false }
            return s == .often || s == .veryEasily
        }()

        let normalizedScanned  = Set(scannedIngredients.map(normalizeIngredient))
        let routineIngredients = currentRoutineIngredients()
        let goodSkinSet        = skinTypeGoodIngredients[skinType] ?? []
        let goodConcernSet     = Set(concerns.flatMap { concernGoodIngredients[$0] ?? [] })

        // 1. Routine conflicts → avoid
        var avoid: [CategorisedIngredient] = []
        var conflictIngredientKeys = Set<String>()

        for pair in allConflictPairs {
            guard pair.count == 2 else { continue }
            let first  = normalizeIngredient(pair[0])
            let second = normalizeIngredient(pair[1])
            let productHasFirst  = normalizedScanned.contains(first)
            let productHasSecond = normalizedScanned.contains(second)
            let routineHasFirst  = routineIngredients.contains(first)
            let routineHasSecond = routineIngredients.contains(second)

            var conflictKey: String?
            var conflictOther: String?
            if productHasFirst && (productHasSecond || routineHasSecond) {
                conflictKey = first; conflictOther = second
            } else if productHasSecond && routineHasFirst {
                conflictKey = second; conflictOther = first
            }

            if let ck = conflictKey, let co = conflictOther,
               conflictIngredientKeys.insert(ck).inserted {
                avoid.append(CategorisedIngredient(
                    name:        displayName(for: ck),
                    explanation: "Conflicts with \(displayName(for: co)) in your routine",
                    category:    .avoid
                ))
            }
        }

        // 2. Categorise remaining
        var goodForYou: [CategorisedIngredient]     = []
        var useWithCaution: [CategorisedIngredient] = []

        for ingredient in normalizedScanned.sorted() {
            guard !conflictIngredientKeys.contains(ingredient) else { continue }
            let displayN        = displayName(for: ingredient)
            let note            = ingredientExplanations[ingredient] ?? ""
            let isInRoutine     = routineIngredients.contains(ingredient)
            let isGoodForType   = goodSkinSet.contains(ingredient)
            let isGoodForConc   = goodConcernSet.contains(ingredient)
            let isCautionActive = cautionIngredientSet.contains(ingredient)

            if isInRoutine || isGoodForType || isGoodForConc {
                if isSensitive && isCautionActive {
                    useWithCaution.append(CategorisedIngredient(
                        name:        displayN,
                        explanation: note.isEmpty ? "Strong active — patch-test before using" : note,
                        category:    .useWithCaution
                    ))
                } else {
                    goodForYou.append(CategorisedIngredient(
                        name:        displayN,
                        explanation: note.isEmpty ? "Matches your skin profile" : note,
                        category:    .goodForYou
                    ))
                }
            } else if isCautionActive {
                useWithCaution.append(CategorisedIngredient(
                    name:        displayN,
                    explanation: note.isEmpty ? "Strong active — introduce gradually" : note,
                    category:    .useWithCaution
                ))
            }
            // else: formulation ingredient (thickener, preservative) — listed in detectedIngredients only
        }

        // 3. Verdict
        let verdict: ScanVerdict
        let verdictReason: String

        if !avoid.isEmpty {
            verdict = .notRecommended
            let names = avoid.map(\.name).joined(separator: ", ")
            verdictReason = "\(names) \(avoid.count == 1 ? "conflicts" : "conflict") with your current routine."
        } else if !goodForYou.isEmpty {
            verdict = .recommended
            let skinName = skinType.rawValue.capitalized
            if !concerns.isEmpty {
                let top = concerns.prefix(2).map(\.displayName).joined(separator: " & ")
                verdictReason = "Key ingredients suit your \(skinName.lowercased()) skin and help with \(top)."
            } else {
                verdictReason = "Key ingredients are well-suited for your \(skinName.lowercased()) skin type."
            }
        } else if !useWithCaution.isEmpty {
            verdict = .useWithCaution
            verdictReason = "Contains active ingredients — patch-test and introduce one at a time."
        } else {
            verdict = .useWithCaution
            verdictReason = "Ingredients detected but none match your current profile — this may be a basic moisturiser or cleanser."
        }

        return ScanAnalysisResult(
            verdict:             verdict,
            verdictReason:       verdictReason,
            goodForYou:          goodForYou,
            useWithCaution:      useWithCaution,
            avoid:               avoid,
            detectedIngredients: scannedIngredients
        )
    }

    // MARK: - Relevance check

    private func checkLooksLikeSkincare(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let lower = text.lowercased()

        // A real ingredient list has many commas
        let commaCount = lower.components(separatedBy: ",").count - 1
        guard commaCount >= 3 else {
            // Still pass if it explicitly says "ingredients"
            return lower.contains("ingredients") || lower.contains("inci")
        }

        // Must also contain at least one cosmetic-specific term
        return skincareMarkers.contains(where: { lower.contains($0) })
    }

    // MARK: - Private helpers

    private func containsPhrase(_ phrase: String, in text: String) -> Bool {
        " \(text) ".contains(" \(normalize(phrase)) ")
    }

    private func matchesIngredientTokens(ingredient: String, aliases: [String], textTokens: Set<String>) -> Bool {
        ingredientTokenCandidates(for: ingredient, aliases: aliases).contains { candidate in
            let candidateTokens = significantTokens(in: candidate)
            guard !candidateTokens.isEmpty else { return false }
            return candidateTokens.isSubset(of: textTokens)
        }
    }

    private func ingredientTokenCandidates(for ingredient: String, aliases: [String]) -> [String] {
        Array(Set([ingredient] + aliases))
    }

    private func significantTokens(in text: String) -> Set<String> {
        Set(
            normalize(text).split(separator: " ").map(String.init)
                .filter { $0.count > 2 && !weakIngredientTokens.contains($0) }
        )
    }

    private func displayName(for ingredient: String) -> String {
        AppDataModel.shared.ingredient(named: ingredient)?.name ?? ingredient.capitalized
    }

    private func deduplicatedConflictPairs(from pairs: [[String]]) -> [[String]] {
        var seen   = Set<String>()
        var result = [[String]]()
        for pair in pairs where pair.count == 2 {
            let normalized = pair.map(normalizeIngredient).sorted()
            guard normalized.count == 2, normalized[0] != normalized[1] else { continue }
            let key = normalized.joined(separator: "::")
            if seen.insert(key).inserted { result.append(normalized) }
        }
        return result
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9,]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+",         with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeIngredient(_ ingredient: String) -> String {
        let normalized = normalize(ingredient)
        if normalized == "alpha hydroxy acid" { return "aha" }
        return normalized
    }

    private func currentRoutineIngredients() -> Set<String> {
        let currentUserID   = dataModel.currentUser().id
        let jsonIngredients = dataModel.routineStepsForHomeScreen(for: currentUserID)
            .flatMap { dataModel.ingredientNames(for: $0) }
        let aiIngredients   = AppDataModel.shared.aiRoutineIngredients().flatMap { $0.ingredients }
        let fallback        = routine.values.flatMap { $0 }
        return Set((fallback + jsonIngredients + aiIngredients).map(normalizeIngredient))
    }
}

// MARK: - AppDataModel helpers

private extension AppDataModel {
    func aiRoutineIngredients() -> [(step: String, ingredients: [String])] {
        guard let aiRoutine else { return [] }
        return (aiRoutine.morning + aiRoutine.evening).map {
            (step: $0.productType.rawValue, ingredients: $0.keyIngredients)
        }
    }
}
