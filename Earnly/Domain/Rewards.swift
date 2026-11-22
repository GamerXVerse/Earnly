import Foundation

public enum RewardError: Error, Equatable, Sendable {
    case ledgerCapacityExceeded
}

/// One credit per completed session. Activation and threshold evidence are separate.
/// A reached threshold establishes a lower bound on consumption, never exact use.
public struct RewardTransaction: Codable, Equatable, Identifiable, Sendable {
    public var id: PracticeSession.ID { sessionID }
    public let sessionID: PracticeSession.ID
    public let earnedMinutes: Int
    public let earnedAt: Date
    public internal(set) var activatedAt: Date?
    public internal(set) var thresholdReachedAt: Date?

    public var consumedAtLeastMinutes: Int? {
        thresholdReachedAt == nil ? nil : earnedMinutes
    }
}

/// Uses a single session key for retries, accounting and persisted uniqueness.
public struct RewardLedger: Codable, Equatable, Sendable {
    public internal(set) var transactions: [PracticeSession.ID: RewardTransaction] = [:]

    init() {}

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        transactions = try fields.decode([PracticeSession.ID: RewardTransaction].self, forKey: .transactions)
        guard hasValidTotal else {
            throw DecodingError.dataCorruptedError(forKey: .transactions, in: fields,
                                                  debugDescription: "Invalid earned minutes")
        }
    }

    public var totalEarnedMinutes: Int {
        // The store validates the sum on load and before adding a credit.
        transactions.values.reduce(0) { $0 + $1.earnedMinutes }
    }

    var hasValidTotal: Bool {
        var total = 0
        for transaction in transactions.values {
            let (sum, overflow) = total.addingReportingOverflow(transaction.earnedMinutes)
            guard transaction.earnedMinutes > 0, !overflow else { return false }
            total = sum
        }
        return true
    }
}
