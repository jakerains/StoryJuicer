import Foundation

// MARK: - Creation Mode

enum CreationMode: String, CaseIterable, Identifiable, Sendable {
    case quick
    case guided
    case author

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quick: return "Quick"
        case .guided: return "Guided"
        case .author: return "Author"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "Enter your idea and go"
        case .guided: return "AI asks questions to enrich your story"
        case .author: return "Write your own story, get AI illustrations"
        }
    }

    var iconName: String {
        switch self {
        case .quick: return "hare"
        case .guided: return "sparkle.magnifyingglass"
        case .author: return "pencil.and.outline"
        }
    }
}

// MARK: - Audience Mode

enum AudienceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case kid
    case adult

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kid: return "For Kids"
        case .adult: return "For Everyone"
        }
    }

    var subtitle: String {
        switch self {
        case .kid: return "Simple, playful language (ages 3-8)"
        case .adult: return "Richer vocabulary and themes"
        }
    }

    var iconName: String {
        switch self {
        case .kid: return "teddybear"
        case .adult: return "person.2"
        }
    }
}

// MARK: - Q&A Data Models

struct StoryQuestion: Identifiable, Sendable, Equatable {
    let id: UUID
    let questionText: String
    let suggestedAnswers: [String]
    var userAnswer: String

    var isAnswered: Bool {
        !userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(questionText: String, suggestedAnswers: [String], userAnswer: String = "") {
        self.id = UUID()
        self.questionText = questionText
        self.suggestedAnswers = suggestedAnswers
        self.userAnswer = userAnswer
    }
}

struct StoryQARound: Identifiable, Sendable, Equatable {
    let id: UUID
    let roundNumber: Int
    var questions: [StoryQuestion]

    var isComplete: Bool {
        questions.allSatisfy(\.isAnswered)
    }

    var answeredCount: Int {
        questions.filter(\.isAnswered).count
    }

    init(roundNumber: Int, questions: [StoryQuestion]) {
        self.id = UUID()
        self.roundNumber = roundNumber
        self.questions = questions
    }
}

// MARK: - Q&A Phase

enum StoryQAPhase: Sendable, Equatable {
    case idle
    case generatingQuestions
    case awaitingAnswers(round: Int, isFinalRound: Bool)
    case compilingConcept
    case complete(enrichedConcept: String)
    case failed(String)

    var isWorking: Bool {
        switch self {
        case .generatingQuestions, .compilingConcept: return true
        default: return false
        }
    }

    func roundLabel(audience: AudienceMode = .kid) -> String {
        switch self {
        case .awaitingAnswers(let round, _):
            let focus: String
            switch (round, audience) {
            case (1, .kid):  focus = "Hero & World"
            case (1, .adult): focus = "Characters & Setting"
            case (2, .kid):  focus = "Adventure & Problem"
            case (2, .adult): focus = "Plot & Conflict"
            case (_, .kid):  focus = "Ending & Feelings"
            case (_, .adult): focus = "Tone & Resolution"
            }
            return "Round \(round) — \(focus)"
        default:
            return ""
        }
    }
}

// MARK: - Question DTO (for JSON decoding)

struct QuestionDTO: Decodable, Sendable {
    let question: String
    let suggestions: [String]

    func toStoryQuestion() -> StoryQuestion {
        StoryQuestion(
            questionText: question,
            suggestedAnswers: Array(suggestions.prefix(3))
        )
    }
}

/// Wrapper DTO for the dynamic Q&A response format.
/// The model returns `{"questions": [...], "done": true/false}`.
struct QARoundResponseDTO: Decodable, Sendable {
    let questions: [QuestionDTO]
    let done: Bool
}
