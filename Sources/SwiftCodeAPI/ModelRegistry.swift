// MARK: - ModelInfo
// Cost data sourced from the TypeScript reference: utils/modelCost.ts
// All costs are in USD per 1,000,000 tokens (per-Mtok).

/// Metadata and pricing for a single Anthropic model.
public struct ModelInfo: Sendable, Equatable {
    public let id: String                          // First-party model ID (canonical)
    public let displayName: String
    public let contextWindow: Int
    public let maxOutputTokens: Int
    /// Input cost in USD per 1M tokens.
    public let inputCostPer1MTokens: Double
    /// Output cost in USD per 1M tokens.
    public let outputCostPer1MTokens: Double
    /// Prompt cache read cost per 1M tokens (nil if caching not supported).
    public let cacheReadCostPer1MTokens: Double?
    /// Prompt cache write (creation) cost per 1M tokens.
    public let cacheWriteCostPer1MTokens: Double?
    /// Web search cost per request (USD).
    public let webSearchCostPerRequest: Double

    // Bedrock / Vertex / Foundry identifiers for cross-provider resolution
    public let bedrockID: String?
    public let vertexID: String?
    public let foundryID: String?

    public init(
        id: String,
        displayName: String,
        contextWindow: Int,
        maxOutputTokens: Int,
        inputCostPer1MTokens: Double,
        outputCostPer1MTokens: Double,
        cacheReadCostPer1MTokens: Double? = nil,
        cacheWriteCostPer1MTokens: Double? = nil,
        webSearchCostPerRequest: Double = 0.01,
        bedrockID: String? = nil,
        vertexID: String? = nil,
        foundryID: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.inputCostPer1MTokens = inputCostPer1MTokens
        self.outputCostPer1MTokens = outputCostPer1MTokens
        self.cacheReadCostPer1MTokens = cacheReadCostPer1MTokens
        self.cacheWriteCostPer1MTokens = cacheWriteCostPer1MTokens
        self.webSearchCostPerRequest = webSearchCostPerRequest
        self.bedrockID = bedrockID
        self.vertexID = vertexID
        self.foundryID = foundryID
    }
}

// MARK: - ModelRegistry

/// Static registry of known Anthropic models with their pricing and metadata.
/// Matches ALL_MODEL_CONFIGS + MODEL_COSTS from the TypeScript reference.
public enum ModelRegistry {

    // MARK: Model Definitions
    // Prices from https://platform.claude.com/docs/en/about-claude/pricing
    // Reference: utils/modelCost.ts cost tier constants

    public static let models: [ModelInfo] = [

        // --- Haiku 3.5 --- ($0.80 / $4 per Mtok) COST_HAIKU_35
        ModelInfo(
            id: "claude-3-5-haiku-20241022",
            displayName: "Haiku 3.5",
            contextWindow: 200_000,
            maxOutputTokens: 8_192,
            inputCostPer1MTokens: 0.8,
            outputCostPer1MTokens: 4.0,
            cacheReadCostPer1MTokens: 0.08,
            cacheWriteCostPer1MTokens: 1.0,
            bedrockID: "us.anthropic.claude-3-5-haiku-20241022-v1:0",
            vertexID: "claude-3-5-haiku@20241022",
            foundryID: "claude-3-5-haiku"
        ),

        // --- Haiku 4.5 --- ($1 / $5 per Mtok) COST_HAIKU_45
        ModelInfo(
            id: "claude-haiku-4-5-20251001",
            displayName: "Haiku 4.5",
            contextWindow: 200_000,
            maxOutputTokens: 16_000,
            inputCostPer1MTokens: 1.0,
            outputCostPer1MTokens: 5.0,
            cacheReadCostPer1MTokens: 0.1,
            cacheWriteCostPer1MTokens: 1.25,
            bedrockID: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            vertexID: "claude-haiku-4-5@20251001",
            foundryID: "claude-haiku-4-5"
        ),

        // --- Sonnet 3.5 v2 --- ($3 / $15 per Mtok) COST_TIER_3_15
        ModelInfo(
            id: "claude-3-5-sonnet-20241022",
            displayName: "Sonnet 3.5 v2",
            contextWindow: 200_000,
            maxOutputTokens: 8_192,
            inputCostPer1MTokens: 3.0,
            outputCostPer1MTokens: 15.0,
            cacheReadCostPer1MTokens: 0.3,
            cacheWriteCostPer1MTokens: 3.75,
            bedrockID: "anthropic.claude-3-5-sonnet-20241022-v2:0",
            vertexID: "claude-3-5-sonnet-v2@20241022",
            foundryID: "claude-3-5-sonnet"
        ),

        // --- Sonnet 3.7 --- ($3 / $15 per Mtok) COST_TIER_3_15
        ModelInfo(
            id: "claude-3-7-sonnet-20250219",
            displayName: "Sonnet 3.7",
            contextWindow: 200_000,
            maxOutputTokens: 16_000,
            inputCostPer1MTokens: 3.0,
            outputCostPer1MTokens: 15.0,
            cacheReadCostPer1MTokens: 0.3,
            cacheWriteCostPer1MTokens: 3.75,
            bedrockID: "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
            vertexID: "claude-3-7-sonnet@20250219",
            foundryID: "claude-3-7-sonnet"
        ),

        // --- Sonnet 4 --- ($3 / $15 per Mtok) COST_TIER_3_15
        ModelInfo(
            id: "claude-sonnet-4-20250514",
            displayName: "Sonnet 4",
            contextWindow: 200_000,
            maxOutputTokens: 16_000,
            inputCostPer1MTokens: 3.0,
            outputCostPer1MTokens: 15.0,
            cacheReadCostPer1MTokens: 0.3,
            cacheWriteCostPer1MTokens: 3.75,
            bedrockID: "us.anthropic.claude-sonnet-4-20250514-v1:0",
            vertexID: "claude-sonnet-4@20250514",
            foundryID: "claude-sonnet-4"
        ),

        // --- Sonnet 4.5 --- ($3 / $15 per Mtok) COST_TIER_3_15
        ModelInfo(
            id: "claude-sonnet-4-5-20250929",
            displayName: "Sonnet 4.5",
            contextWindow: 200_000,
            maxOutputTokens: 16_000,
            inputCostPer1MTokens: 3.0,
            outputCostPer1MTokens: 15.0,
            cacheReadCostPer1MTokens: 0.3,
            cacheWriteCostPer1MTokens: 3.75,
            bedrockID: "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
            vertexID: "claude-sonnet-4-5@20250929",
            foundryID: "claude-sonnet-4-5"
        ),

        // --- Sonnet 4.6 --- ($3 / $15 per Mtok) COST_TIER_3_15
        ModelInfo(
            id: "claude-sonnet-4-6",
            displayName: "Sonnet 4.6",
            contextWindow: 200_000,
            maxOutputTokens: 16_000,
            inputCostPer1MTokens: 3.0,
            outputCostPer1MTokens: 15.0,
            cacheReadCostPer1MTokens: 0.3,
            cacheWriteCostPer1MTokens: 3.75,
            bedrockID: "us.anthropic.claude-sonnet-4-6",
            vertexID: "claude-sonnet-4-6",
            foundryID: "claude-sonnet-4-6"
        ),

        // --- Opus 4 --- ($15 / $75 per Mtok) COST_TIER_15_75
        ModelInfo(
            id: "claude-opus-4-20250514",
            displayName: "Opus 4",
            contextWindow: 200_000,
            maxOutputTokens: 16_000,
            inputCostPer1MTokens: 15.0,
            outputCostPer1MTokens: 75.0,
            cacheReadCostPer1MTokens: 1.5,
            cacheWriteCostPer1MTokens: 18.75,
            bedrockID: "us.anthropic.claude-opus-4-20250514-v1:0",
            vertexID: "claude-opus-4@20250514",
            foundryID: "claude-opus-4"
        ),

        // --- Opus 4.1 --- ($15 / $75 per Mtok) COST_TIER_15_75
        ModelInfo(
            id: "claude-opus-4-1-20250805",
            displayName: "Opus 4.1",
            contextWindow: 200_000,
            maxOutputTokens: 16_000,
            inputCostPer1MTokens: 15.0,
            outputCostPer1MTokens: 75.0,
            cacheReadCostPer1MTokens: 1.5,
            cacheWriteCostPer1MTokens: 18.75,
            bedrockID: "us.anthropic.claude-opus-4-1-20250805-v1:0",
            vertexID: "claude-opus-4-1@20250805",
            foundryID: "claude-opus-4-1"
        ),

        // --- Opus 4.5 --- ($5 / $25 per Mtok) COST_TIER_5_25
        ModelInfo(
            id: "claude-opus-4-5-20251101",
            displayName: "Opus 4.5",
            contextWindow: 200_000,
            maxOutputTokens: 16_000,
            inputCostPer1MTokens: 5.0,
            outputCostPer1MTokens: 25.0,
            cacheReadCostPer1MTokens: 0.5,
            cacheWriteCostPer1MTokens: 6.25,
            bedrockID: "us.anthropic.claude-opus-4-5-20251101-v1:0",
            vertexID: "claude-opus-4-5@20251101",
            foundryID: "claude-opus-4-5"
        ),

        // --- Opus 4.6 --- ($5 / $25 per Mtok standard; $30/$150 fast mode) COST_TIER_5_25 / COST_TIER_30_150
        ModelInfo(
            id: "claude-opus-4-6",
            displayName: "Opus 4.6",
            contextWindow: 200_000,
            maxOutputTokens: 16_000,
            inputCostPer1MTokens: 5.0,
            outputCostPer1MTokens: 25.0,
            cacheReadCostPer1MTokens: 0.5,
            cacheWriteCostPer1MTokens: 6.25,
            bedrockID: "us.anthropic.claude-opus-4-6-v1",
            vertexID: "claude-opus-4-6",
            foundryID: "claude-opus-4-6"
        ),
    ]

    // MARK: Aliases
    // Maps short aliases → canonical first-party model ID.
    // Matches MODEL_ALIASES in aliases.ts + getDefault*Model() in model.ts.

    private static let aliases: [String: String] = [
        // Family aliases → latest model in that family
        "opus":   "claude-opus-4-6",
        "sonnet": "claude-sonnet-4-6",
        "haiku":  "claude-haiku-4-5-20251001",
        "best":   "claude-opus-4-6",

        // 1M-context aliases (same model, context unlocked via beta header)
        "opus[1m]":   "claude-opus-4-6",
        "sonnet[1m]": "claude-sonnet-4-6",
        "opusplan":   "claude-opus-4-6",

        // Version shorthands
        "claude-haiku-4-5":  "claude-haiku-4-5-20251001",
        "claude-sonnet-4-6": "claude-sonnet-4-6",
        "claude-opus-4-6":   "claude-opus-4-6",
    ]

    // MARK: Lookup

    /// Returns the ModelInfo for the given ID or alias. Returns nil for unknowns.
    public static func resolve(_ aliasOrId: String) -> ModelInfo? {
        let id = aliases[aliasOrId] ?? aliasOrId
        return models.first { $0.id == id }
    }

    /// Returns the canonical first-party model ID for a given alias or ID.
    public static func canonicalID(_ aliasOrId: String) -> String? {
        let id = aliases[aliasOrId] ?? aliasOrId
        return models.first { $0.id == id }?.id
    }

    /// Best (highest-capability) model available.
    public static var bestModel: ModelInfo { resolve("claude-opus-4-6")! }

    /// Default main-loop model (Sonnet 4.6 per reference).
    public static var defaultMainLoopModel: ModelInfo { resolve("claude-sonnet-4-6")! }

    /// Default small/fast model (Haiku 4.5 per reference).
    public static var defaultSmallFastModel: ModelInfo { resolve("claude-haiku-4-5-20251001")! }
}
