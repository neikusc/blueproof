//
//  OpenAIClient.swift
//  BlueProof
//
//  Created by Kien Trinh on 1/12/26.
//

import Foundation

enum OpenAIClient {
    // ✅ For best results, DO NOT hardcode your key in an app.
    // For personal testing you can set it here, but safer is:
    // - Call your own proxy endpoint that injects the key server-side.
    
    // Choose a model from OpenAI's models page (example: "gpt-4o-mini" or newer).
    // See: https://platform.openai.com/docs/models
    static let model = "gpt-4o-mini"
    
    struct ResponsesRequest: Encodable {
        let model: String
        let input: [InputItem]
        
        struct InputItem: Encodable {
            let role: String
            let content: [ContentPart]
        }
        
        struct ContentPart: Encodable {
            let type: String
            let text: String
        }
    }
    
    struct ResponsesResponse: Decodable {
        let output: [OutputItem]?
        
        struct OutputItem: Decodable {
            let content: [OutputContent]?
        }
        
        struct OutputContent: Decodable {
            let type: String?
            let text: String?
        }
    }
    
    static func correct(systemPrompt: String, userText: String) async throws -> String {
        // Build request body using Responses API
        // POST https://api.openai.com/v1/responses
        // Docs: Responses endpoint  [oai_citation:2‡OpenAI Platform](https://platform.openai.com/docs/api-reference/responses?_clear=true&lang=javascript&utm_source=chatgpt.com)
        
        let body = ResponsesRequest(
            model: model,
            input: [
                .init(role: "system", content: [.init(type: "input_text", text: systemPrompt)]),
                .init(role: "user", content: [.init(type: "input_text", text: userText)])
            ]
        )
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        guard let apiKey = KeychainService.loadApiKey() else {
            throw NSError(
                domain: "BlueProof",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not set"]
            )
        }
        
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") // Bearer auth  [oai_citation:3‡OpenAI Platform](https://platform.openai.com/docs/api-reference/introduction?utm_source=chatgpt.com)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: text])
        }
        
        let decoded = try JSONDecoder().decode(ResponsesResponse.self, from: data)
        
        // Extract first text block we can find
        let text = decoded.output?
            .compactMap { $0.content }
            .flatMap { $0 }
            .first(where: { ($0.type ?? "") == "output_text" || $0.text != nil })?
            .text
        
        return text ?? ""
    }
}
