//
//  OpenAIService.swift
//  Tone
//
//  Created by Muukii on 2025/04/15.
//  Copyright © 2025 MuukLab. All rights reserved.
//

import Alamofire
import Foundation

public final class OpenAIService {

  public enum Error: Swift.Error {
    case invalidResponse
    case underlying(Swift.Error)
  }


  private let apiKey: String
  private let baseURL: URL = URL(string: "https://api.openai.com/v1")!

  public init(apiKey: String) {
    self.apiKey = apiKey
  }

  private var headers: HTTPHeaders {
    [
      "Authorization": "Bearer \(apiKey)",
      "Content-Type": "application/json",
    ]
  }

  public func createResponse(
    input: [ResponseInput],
    model: String = "gpt-4.1-nano",
    temperature: Double = 1,
    maxOutputTokens: Int = 2048,
    topP: Double = 1,
    store: Bool = true
  ) async throws(Error) -> Sentences {

    let parameters = CreateResponseParameters(
      input: input.map { $0.dictionary },
      model: model,
      tools: [],
      text: TextFormat(
        format: Format(
          strict: true,
          type: "json_schema",
          name: "sentence_creation",
          schema: Schema(
            properties: SchemaProperties(
              words: ArrayProperty(
                type: "array",
                items: StringProperty(type: "string"),
                description: "An array of words or expressions to be used in sentence construction."
              ),
              sentences: ArrayProperty(
                type: "array",
                items: SentenceProperty(
                  properties: SentencePropertyDetails(
                    word: StringProperty(
                      type: "string",
                      description: "The word or expression included in the sentence."
                    ),
                    sentence: StringProperty(
                      type: "string",
                      description:
                        "A sentence constructed to naturally include the word or expression."
                    )
                  ),
                  type: "object",
                  required: ["word", "sentence"],
                  additionalProperties: false
                ),
                description:
                  "A collection of sentences created using the provided words or expressions."
              )
            ),
            type: "object",
            required: ["words", "sentences"],
            additionalProperties: false
          )
        )
      ),
      reasoning: [:],
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
      topP: topP,
      store: store
    )

    let encoder = JSONEncoder()

    do {
      let data = try encoder.encode(parameters)
      let jsonString = String(data: data, encoding: .utf8) ?? "{}"

      let response = try await AF.request(
        baseURL.appendingPathComponent("responses"),
        method: .post,
        parameters: [:],
        encoding: JSONStringEncoding(jsonString),
        headers: headers
      )
      .serializingDecodable(ResponseOutput.self)
      .value

      guard let first = response.output.first?.content.first else {
        throw Error.invalidResponse
      }

      return try .init(jsonString: first.text)
    } catch {
      throw Error.underlying(error)
    }
  }
    
  public enum TranscribeError: Swift.Error {
    case invalidResponse
    case underlying(Swift.Error)
    case fileTooLarge(maxSize: Int)
    case fileNotFound
  }
  
  public enum TranscriptionModel: String, CaseIterable {    
    case whisper1 = "whisper-1"
    case gpt_4o_mini = "gpt-4o-mini-transcribe"
    case gpt_4o = "gpt-4o-transcribe"
  }

  public func transcribe(
    fileURL: URL,
    model: TranscriptionModel = .whisper1
  ) async throws(TranscribeError) -> Responses.Transcription {
    
    Log.debug("Transcribing file: \(fileURL)")
    
    do {
      let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      let maxSize = 25 * 1024 * 1024 // 25MB
      
      guard fileSize <= maxSize else {
        throw TranscribeError.fileTooLarge(maxSize: maxSize)
      }
            
      let result = try await AF.upload(
        multipartFormData: { form in
          form.append(
            fileURL,
            withName: "file",
            fileName: fileURL.lastPathComponent,
            mimeType: "audio/mpeg"
          )
          form.append("word".data(using: .utf8)!, withName: "timestamp_granularities[]")
          form.append(model.rawValue.data(using: .utf8)!, withName: "model")
          form.append("verbose_json".data(using: .utf8)!, withName: "response_format")
          form.append("en".data(using: .utf8)!, withName: "language")
        },
        to: baseURL.appendingPathComponent("/audio/transcriptions"),
        usingThreshold: 0,
        method: .post,
        headers: headers,
        interceptor: nil
      )
        .serializingDecodable(Responses.Transcription.self)
        .value
      
      Log.debug("Transcription completed")
      
      return result
    } catch {
      assertionFailure(error.localizedDescription)
      throw TranscribeError.underlying(error)
    }
  }

}

// MARK: - Models
extension OpenAIService {

  public enum Responses {
    public struct Transcription: Decodable, Sendable {

      public struct Word: Decodable, Sendable {
        var word: String
        var start: Double
        var end: Double
      }

      var task: String
      var language: String
      var duration: Double
      var text: String
      var words: [Word]
    }
  }

  public struct Sentences: Decodable, Sendable {
    public let words: [String]
    public let sentences: [Sentence]

    public struct Sentence: Decodable, Sendable {
      public let word: String
      public let sentence: String
    }

    public init(jsonString: String) throws {
      let data = jsonString.data(using: .utf8)!
      let decoder = JSONDecoder()
      self = try decoder.decode(Sentences.self, from: data)
    }
  }

  public struct Message: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
      self.role = role
      self.content = content
    }

    var dictionary: [String: String] {
      [
        "role": role,
        "content": content,
      ]
    }
  }

  public struct ChatResponse: Decodable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]
    public let usage: Usage

    public struct Choice: Decodable, Sendable {
      public let index: Int
      public let message: Message
      public let finishReason: String

      private enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
      }
    }

    public struct Usage: Decodable, Sendable {
      public let promptTokens: Int
      public let completionTokens: Int
      public let totalTokens: Int

      private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
      }
    }
  }

  public struct ResponseInput: Codable, Sendable {
    public let content: [Content]
    public let role: String

    public init(content: [Content], role: String) {
      self.content = content
      self.role = role
    }

    var dictionary: [String: String] {
      [
        "content": content.map { $0.dictionary }.description,
        "role": role,
      ]
    }

    public struct Content: Codable, Sendable {
      public let type: String
      public let text: String

      public init(type: String, text: String) {
        self.type = type
        self.text = text
      }

      var dictionary: [String: String] {
        [
          "type": type,
          "text": text,
        ]
      }
    }
  }

  public struct ResponseOutput: Decodable, Sendable {

    public struct Output: Decodable, Sendable {

      public struct Content: Decodable, Sendable {
        public let type: String
        public let text: String

        public init(type: String, text: String) {
          self.type = type
          self.text = text
        }
      }

      public let content: [Content]

    }

    public let id: String
    public let object: String
    public let created_at: Int
    public let model: String
    public let output: [Output]

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(String.self, forKey: .id)
      object = try container.decode(String.self, forKey: .object)
      created_at = try container.decode(Int.self, forKey: .created_at)
      model = try container.decode(String.self, forKey: .model)
      output = try container.decode(Array<Output>.self, forKey: .output)
    }

    private enum CodingKeys: String, CodingKey {
      case id
      case object
      case created_at
      case model
      case output
    }
  }

  private struct CreateResponseParameters: Encodable, Sendable {
    let input: [[String: String]]
    let model: String
    let tools: [String]
    let text: TextFormat
    let reasoning: [String: String]
    let temperature: Double
    let maxOutputTokens: Int
    let topP: Double
    let store: Bool

    private enum CodingKeys: String, CodingKey {
      case input
      case model
      case tools
      case text
      case reasoning
      case temperature
      case maxOutputTokens = "max_output_tokens"
      case topP = "top_p"
      case store
    }
  }

  private struct TextFormat: Encodable, Sendable {
    let format: Format
  }

  private struct Format: Encodable, Sendable {
    let strict: Bool
    let type: String
    let name: String
    let schema: Schema
  }

  private struct Schema: Encodable, Sendable {
    let properties: SchemaProperties
    let type: String
    let required: [String]
    let additionalProperties: Bool
  }

  private struct SchemaProperties: Encodable, Sendable {
    let words: ArrayProperty
    let sentences: ArrayProperty
  }

  private struct ArrayProperty: Encodable, Sendable {
    let type: String
    let items: SendableEncodable
    let description: String

    private enum CodingKeys: String, CodingKey {
      case type
      case items
      case description
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(items, forKey: .items)
      try container.encode(description, forKey: .description)
    }
  }

  private protocol SendableEncodable: Encodable, Sendable {}

  private struct StringProperty: SendableEncodable {
    let type: String
    let description: String?

    init(type: String, description: String? = nil) {
      self.type = type
      self.description = description
    }
  }

  private struct SentenceProperty: SendableEncodable {
    let properties: SentencePropertyDetails
    let type: String
    let required: [String]
    let additionalProperties: Bool
  }

  private struct SentencePropertyDetails: SendableEncodable {
    let word: StringProperty
    let sentence: StringProperty
  }

  private struct JSONStringEncoding: ParameterEncoding {
    private let jsonString: String

    init(_ jsonString: String) {
      self.jsonString = jsonString
    }

    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws
      -> URLRequest
    {
      var request = try urlRequest.asURLRequest()
      request.httpBody = jsonString.data(using: .utf8)
      return request
    }
  }
}
