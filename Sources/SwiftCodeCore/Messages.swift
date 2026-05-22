// MARK: - JSONValue
// Generic JSON value type for arbitrary tool input/output. Matches the
// TypeScript pattern where tool inputs are Record<string, unknown>.

public indirect enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([JSONValue].self) {
            self = .array(v)
        } else if let v = try? container.decode([String: JSONValue].self) {
            self = .object(v)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown JSON value type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let v):
            try container.encode(v)
        case .int(let v):
            try container.encode(v)
        case .double(let v):
            try container.encode(v)
        case .string(let v):
            try container.encode(v)
        case .array(let v):
            try container.encode(v)
        case .object(let v):
            try container.encode(v)
        }
    }
}

// MARK: - Usage

/// Token usage from an API response.
public struct Usage: Codable, Equatable, Sendable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadInputTokens: Int?
    public var cacheCreationInputTokens: Int?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheReadInputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
    }
}

// MARK: - StopReason

/// Why an assistant turn ended.
public enum StopReason: String, Codable, Equatable, Sendable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case toolUse = "tool_use"
    case stopSequence = "stop_sequence"
}

// MARK: - UserContent

/// The content of a user message.
public enum UserContent: Codable, Equatable, Sendable {
    case text(String)
    case toolResult(id: String, content: [AssistantContent])
    case image(mediaType: String, data: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, toolUseId, content, mediaType, data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "tool_result":
            let id = try container.decode(String.self, forKey: .toolUseId)
            let content = try container.decodeIfPresent([AssistantContent].self, forKey: .content) ?? []
            self = .toolResult(id: id, content: content)
        case "image":
            let mediaType = try container.decode(String.self, forKey: .mediaType)
            let data = try container.decode(String.self, forKey: .data)
            self = .image(mediaType: mediaType, data: data)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown UserContent type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolResult(let id, let content):
            try container.encode("tool_result", forKey: .type)
            try container.encode(id, forKey: .toolUseId)
            try container.encode(content, forKey: .content)
        case .image(let mediaType, let data):
            try container.encode("image", forKey: .type)
            try container.encode(mediaType, forKey: .mediaType)
            try container.encode(data, forKey: .data)
        }
    }
}

// MARK: - AssistantContent

/// A single content block in an assistant message.
public enum AssistantContent: Codable, Equatable, Sendable {
    case text(String)
    case thinking(thinking: String, signature: String)
    case toolUse(id: String, name: String, input: [String: JSONValue])

    private enum CodingKeys: String, CodingKey {
        case type, text, thinking, signature, id, name, input
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "thinking":
            let thinking = try container.decode(String.self, forKey: .thinking)
            let signature = try container.decodeIfPresent(String.self, forKey: .signature) ?? ""
            self = .thinking(thinking: thinking, signature: signature)
        case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decodeIfPresent([String: JSONValue].self, forKey: .input) ?? [:]
            self = .toolUse(id: id, name: name, input: input)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown AssistantContent type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .thinking(let thinking, let signature):
            try container.encode("thinking", forKey: .type)
            try container.encode(thinking, forKey: .thinking)
            try container.encode(signature, forKey: .signature)
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        }
    }
}

// MARK: - UserMessage

/// A message sent by the user. Maps to the TypeScript `UserMessage` type.
public struct UserMessage: Codable, Equatable, Sendable {
    public var uuid: String
    public var content: UserContent
    /// When true, this is a meta/system message hidden from the user.
    public var isMeta: Bool

    public init(uuid: String, content: UserContent, isMeta: Bool) {
        self.uuid = uuid
        self.content = content
        self.isMeta = isMeta
    }
}

// MARK: - AssistantMessage

/// A message from the assistant. Maps to the TypeScript `AssistantMessage` type.
public struct AssistantMessage: Codable, Equatable, Sendable {
    public var uuid: String
    public var content: [AssistantContent]
    public var usage: Usage?
    public var stopReason: StopReason?

    public init(
        uuid: String,
        content: [AssistantContent],
        usage: Usage?,
        stopReason: StopReason?
    ) {
        self.uuid = uuid
        self.content = content
        self.usage = usage
        self.stopReason = stopReason
    }
}

// MARK: - SystemMessage

/// A UI-only system message (never sent to the API). Maps to TypeScript `SystemMessage`.
public struct SystemMessage: Codable, Equatable, Sendable {
    public var uuid: String
    public var text: String
    public var subtype: String?

    public init(uuid: String, text: String, subtype: String? = nil) {
        self.uuid = uuid
        self.text = text
        self.subtype = subtype
    }
}

// MARK: - ProgressMessage

/// An in-progress tool streaming message. Maps to TypeScript `ProgressMessage<P>`.
public struct ProgressMessage: Codable, Equatable, Sendable {
    public var uuid: String
    public var toolUseId: String
    /// Opaque progress payload. Stored as JSONValue for flexibility.
    public var data: JSONValue?

    public init(uuid: String, toolUseId: String, data: JSONValue? = nil) {
        self.uuid = uuid
        self.toolUseId = toolUseId
        self.data = data
    }
}

// MARK: - Message

/// Top-level message discriminated union. JSON encoding uses `{"type": "<case>", ...}` to
/// match the TypeScript reference transcript format so session files remain interoperable.
public enum Message: Codable, Equatable, Sendable {
    case user(UserMessage)
    case assistant(AssistantMessage)
    case system(SystemMessage)
    case progress(ProgressMessage)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum MessageType: String, Codable {
        case user, assistant, system, progress
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        switch type {
        case .user:
            self = .user(try UserMessage(from: decoder))
        case .assistant:
            self = .assistant(try AssistantMessage(from: decoder))
        case .system:
            self = .system(try SystemMessage(from: decoder))
        case .progress:
            self = .progress(try ProgressMessage(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .user(let msg):
            try container.encode(MessageType.user, forKey: .type)
            try msg.encode(to: encoder)
        case .assistant(let msg):
            try container.encode(MessageType.assistant, forKey: .type)
            try msg.encode(to: encoder)
        case .system(let msg):
            try container.encode(MessageType.system, forKey: .type)
            try msg.encode(to: encoder)
        case .progress(let msg):
            try container.encode(MessageType.progress, forKey: .type)
            try msg.encode(to: encoder)
        }
    }
}
