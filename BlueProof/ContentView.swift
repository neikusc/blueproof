//
//  ContentView.swift
//  BlueProof
//
//  Created by Kien Trinh on 1/12/26.
//

import SwiftUI

enum BlueProofMode: String, CaseIterable, Identifiable {
    case email = "Email"
    case plainText = "Plain Text"
    case prompt = "Prompt"
    case powerpoint = "PowerPoint"
    
    var id: String { rawValue }
    
    var systemPrompt: String {
        switch self {
        case .email:
            return """
            You are BlueProof, an expert English editor. Rewrite the user's text as a professional email.
            Keep the meaning. Fix grammar, spelling, clarity, and tone. Return only the corrected email.
            """
        case .plainText:
            return """
            You are BlueProof, an expert English editor. Correct grammar, spelling, and clarity.
            Keep the meaning and style. Return only the corrected text.
            """
        case .prompt:
            return """
            You are BlueProof, an expert prompt engineer. Rewrite the user's text into a clear, effective prompt.
            Keep intent, add missing details only if obvious, and remove ambiguity. Return only the improved prompt.
            """
        case .powerpoint:
            return """
            You are BlueProof, an expert presentation editor. Rewrite the user's text for PowerPoint slides:
            concise bullets, parallel structure, clear wording, no long paragraphs. Return only the revised slide text.
            """
        }
    }
}

struct ContentView: View {
    @State private var mode: BlueProofMode = .plainText
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var apiKeyInput = ""
    @State private var showApiKeyPrompt = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    Picker("Mode", selection: $mode) {
                        ForEach(BlueProofMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Input").font(.headline)
                        TextEditor(text: $inputText)
                            .frame(minHeight: 140)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.blue.opacity(0.4)))
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Output").font(.headline)
                            Spacer()
                            Button("Copy") { copyOutput() }
                                .disabled(outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        
                        TextEditor(text: $outputText)
                            .frame(minHeight: 180)
                            .disabled(true)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.blue.opacity(0.4)))
                    }
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            Task { await generate() }
                        } label: {
                            HStack {
                                if isLoading { ProgressView() }
                                Text(isLoading ? "Generating..." : "Generate")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button {
                            clearAll()
                        } label: {
                            Text("Clear")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading && !inputText.isEmpty && !outputText.isEmpty)
                    }
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                            Text("Blue")
                                                .font(.headline.bold())
                                                .foregroundColor(Color(red: 0.05, green: 0.2, blue: 0.6)) // dark blue

                                            Text("Proof")
                                                .font(.headline)
                                                .foregroundColor(.black.opacity(0.6)) // dark font
                                        }
                            Text("Grammar & tone correction for non-native English writers")
                                .font(.footnote)
                                .foregroundColor(.black.opacity(0.7))
                                .multilineTextAlignment(.center)
    //                            .lineLimit(4)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true) // ✅ forces wrapping
                                .padding(.horizontal)
                        }
                    }
                }
                .onAppear {
                    if KeychainService.loadApiKey() == nil {
                        showApiKeyPrompt = true
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showApiKeyPrompt) {
            VStack(spacing: 16) {
                Text("Enter OpenAI API Key")
                    .font(.headline)
                
                SecureField("sk-...", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Save Key") {
                    do {
//                        try KeychainService.saveApiKey(apiKeyInput)
                        try KeychainService.saveApiKey(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines))
                        apiKeyInput = ""
                        showApiKeyPrompt = false
                    } catch {
                        print("Failed to save key")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKeyInput.isEmpty)
                
                Spacer()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private func clearAll() {
        inputText = ""
        outputText = ""
        errorMessage = nil
    }
    
    private func copyOutput() {
        UIPasteboard.general.string = outputText
    }
    
    private func generate() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        
        do {
            let corrected = try await OpenAIClient.correct(
                systemPrompt: mode.systemPrompt,
                userText: inputText
            )
            outputText = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
        }
    }
}
