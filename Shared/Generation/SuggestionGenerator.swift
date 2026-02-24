import Foundation
import FoundationModels

@Generable
struct StoryConceptSuggestions {
    @Guide(description: """
        Exactly 10 unique children's story concepts. Each must have a DIFFERENT main character \
        AND a DIFFERENT activity/theme. Characters can be animals, kids, robots, toys, vehicles, \
        imaginary creatures, talking objects, or anything a child would love. No two concepts \
        should share the same type of character or the same plot idea. Vary the settings widely. \
        Each is one short sentence under 90 characters. No fantasy kingdoms or made-up place names.
        """)
    var concepts: [String]
}

enum SuggestionGenerator {
    /// Generate 10 fresh, diverse story concept suggestions using the on-device Foundation Model.
    /// Returns nil if the model is unavailable or generation fails.
    static func generate() async -> [String]? {
        guard SystemLanguageModel.default.availability == .available else {
            return nil
        }

        do {
            let session = LanguageModelSession(
                instructions: """
                You are a children's story idea generator. \
                Generate warm, imaginative story concepts for ages 3-8. \
                Characters can be animals, children, robots, toys, talking objects, \
                vehicles with personalities, imaginary friends, or anything fun. \
                Mix it up — not every story needs an animal. Include concepts about \
                kids on adventures, a little robot learning something new, a toy that \
                comes alive, a brave fire truck, a cloud who wants to rain glitter. \
                Focus on real emotions and simple adventures — making a friend, \
                learning a skill, solving a small problem, overcoming a fear, or \
                helping someone. \
                IMPORTANT: Every concept must have a DIFFERENT type of main character \
                and a DIFFERENT theme. Do not repeat character types or plot ideas. \
                Vary the settings widely — parks, kitchens, outer space, the ocean, \
                a cozy bedroom, a busy city, a quiet forest, a train ride, and more.
                """
            )

            let options = GenerationOptions(temperature: 1.0)

            let response = try await session.respond(
                to: "Generate 10 children's story concepts. Each must have a completely different kind of main character and a different theme. Mix animals, kids, robots, toys, and imaginative characters.",
                generating: StoryConceptSuggestions.self,
                options: options
            )

            let concepts = response.content.concepts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let deduplicated = deduplicateConcepts(concepts)

            guard deduplicated.count >= 4 else { return nil }
            return Array(deduplicated.prefix(10))
        } catch {
            return nil
        }
    }

    /// Remove concepts that share the same primary character type to guarantee variety.
    private static func deduplicateConcepts(_ concepts: [String]) -> [String] {
        var seenCharacters: Set<String> = []
        var result: [String] = []

        for concept in concepts {
            let lower = concept.lowercased()
            let character = characterKeywords.first { lower.contains($0) }

            if let character {
                if seenCharacters.contains(character) { continue }
                seenCharacters.insert(character)
            }
            result.append(concept)
        }

        return result
    }

    private static let characterKeywords: [String] = [
        // Animals
        "fox", "kitten", "cat", "puppy", "dog", "rabbit", "bunny", "duckling", "duck",
        "otter", "bear", "owl", "squirrel", "penguin", "frog", "turtle", "mouse",
        "hedgehog", "deer", "bird", "robin", "sparrow", "elephant", "lion", "wolf",
        "pig", "horse", "pony", "goat", "sheep", "lamb", "cow", "chicken", "rooster",
        "bee", "ladybug", "snail", "fish", "whale", "dolphin", "octopus", "crab",
        "parrot", "flamingo", "peacock", "tiger", "giraffe", "zebra", "hippo",
        "koala", "kangaroo", "sloth", "chameleon", "gecko", "lizard", "chipmunk",
        "hamster", "raccoon", "badger", "monkey", "panda", "dragon", "unicorn",
        "butterfly", "caterpillar", "firefly", "beaver", "moose", "llama", "alpaca",
        "corgi", "dachshund", "poodle", "beagle", "retriever",
        // Non-animal characters
        "robot", "toy", "teddy", "doll", "truck", "train", "rocket", "spaceship",
        "cloud", "star", "moon", "sun", "raindrop", "snowflake", "crayon", "paintbrush",
        "book", "backpack", "bicycle", "kite", "balloon", "lighthouse", "teapot",
        "boy", "girl", "child", "kid",
    ]

    /// Curated fallback suggestions when Foundation Models are unavailable.
    /// Returns 10 shuffled concepts from a diverse pool.
    static func randomFallback() -> [String] {
        let pool = [
            // Animals
            "A curious fox who starts a little lending library in the park",
            "A shy kitten trying to make friends on the first day of school",
            "A brave duckling swimming across the pond for the first time",
            "A baby bear helping grandma bake a birthday cake",
            "A small owl staying up past bedtime to count the stars",
            "A hedgehog knitting a tiny scarf for a cold caterpillar",
            // Kids
            "A girl who discovers her shadow likes to dance on its own",
            "A boy who builds a fort that becomes the neighborhood clubhouse",
            "Two best friends on a rainy-day scavenger hunt through the house",
            // Toys & objects
            "A little red wagon that dreams of rolling to the top of the hill",
            "A teddy bear who sneaks out at night to tidy up the playroom",
            "A crayon who feels left out because nobody picks the color gray",
            // Robots & vehicles
            "A tiny robot learning to make pancakes for the first time",
            "A fire truck who is afraid of loud sirens",
            // Imaginative
            "A cloud who collects lost kites and returns them to kids below",
            "A star who falls asleep and almost misses her turn to shine",
        ]
        return Array(pool.shuffled().prefix(10))
    }
}
