//
//  WeeklyCheckInData.swift
//  AAINA
//

import Foundation

struct WeeklyCheckInData: Codable {
    var weekKey:   String = ""
    var weekStart: Date   = Date()
    var weekEnd:   Date   = Date()
    var createdAt: Date?  = nil

    var skinCondition:          String   = ""
    var concerns:               [String] = []
    var sleepQuality:           Int      = -1
    var stressLevel:            Float    = 0.5
    var waterIntake:            Int      = 0
    var progressPhotoFileNames: [String] = []
    var additionalNotes:        String   = ""
    var wantsRoutineChange:     Bool     = false
    var routineTarget:          String   = ""   // "morning", "evening", "both"
    var stepsToChange:          [String] = []
    var routineAction:          String   = ""   // "change" or "remove"
    var routineChangeReason:    String   = ""
}
