import Foundation

enum FinancialGoal: String, CaseIterable, Identifiable, Codable {
    case saveMore, understandSpending, controlSubscriptions, emergencyFund, familyFinances

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveMore: return String.localized("Save more money")
        case .understandSpending: return String.localized("Understand spending")
        case .controlSubscriptions: return String.localized("Control subscriptions")
        case .emergencyFund: return String.localized("Build emergency fund")
        case .familyFinances: return String.localized("Manage family finances")
        }
    }

    var systemImage: String {
        switch self {
        case .saveMore: return "banknote"
        case .understandSpending: return "chart.pie"
        case .controlSubscriptions: return "arrow.triangle.2.circlepath"
        case .emergencyFund: return "shield"
        case .familyFinances: return "figure.2.and.child.holdinghands"
        }
    }
}

enum FinancialProfile: String, CaseIterable, Identifiable, Codable {
    case employee, freelancer, student, family, investor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .employee: return String.localized("Employee")
        case .freelancer: return String.localized("Freelancer")
        case .student: return String.localized("Student")
        case .family: return String.localized("Family")
        case .investor: return String.localized("Investor")
        }
    }

    var systemImage: String {
        switch self {
        case .employee: return "briefcase"
        case .freelancer: return "laptopcomputer"
        case .student: return "graduationcap"
        case .family: return "house"
        case .investor: return "chart.line.uptrend.xyaxis"
        }
    }
}
