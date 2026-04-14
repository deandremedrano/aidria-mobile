//
//  ContentView.swift
//  AIdria
//
//  Apple QA Command Center — Mobile
//  Built by Deandre Medrano
//

import SwiftUI
import Combine

// MARK: - Models

struct Message: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp = Date()
}

struct OllamaRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
}

struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaResponse: Codable {
    let message: OllamaMessage
}

// MARK: - Quick Commands

struct QuickCommand: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let prompt: String
}

let quickCommands = [
    QuickCommand(title: "Morning Brief", subtitle: "Start your QA day", icon: "sun.max.fill", color: .orange,
        prompt: "Give me a morning QA briefing for today. Include focus areas, a testing checklist, and an Apple interview tip. I am preparing for Apple QA engineering roles."),
    QuickCommand(title: "Test Plan", subtitle: "Generate test cases", icon: "checklist", color: .blue,
        prompt: "Generate a comprehensive test plan for Apple's Mail app covering functional, edge case, negative, accessibility, and performance tests."),
    QuickCommand(title: "Feedback Report", subtitle: "File a bug report", icon: "ant.fill", color: .red,
        prompt: "Help me write a detailed Apple Feedback Assistant bug report. Ask me to describe the bug I found and then generate a professional report ready to submit at feedbackassistant.apple.com"),
    QuickCommand(title: "Accessibility Audit", subtitle: "WCAG 2.1 check", icon: "accessibility", color: .green,
        prompt: "Perform a detailed accessibility audit for Apple's Safari browser on iOS. Check against WCAG 2.1 and Apple Human Interface Guidelines. Include violations, passes, and top recommendations."),
    QuickCommand(title: "Defect Predict", subtitle: "Analyze risk", icon: "waveform.path.ecg", color: .purple,
        prompt: "Act as a defect prediction engine. Ask me to describe a recent code change, then predict which areas are most likely to have bugs, with risk scores and recommended tests to run."),
    QuickCommand(title: "Interview Prep", subtitle: "Apple QA questions", icon: "person.fill.questionmark", color: .indigo,
        prompt: "Ask me one Apple QA engineering interview question, wait for my answer, then give me detailed feedback with a score out of 10 and tips for improvement. Start with the question now."),
    QuickCommand(title: "XCTest Generator", subtitle: "Swift test code", icon: "swift", color: Color(red: 0.9, green: 0.4, blue: 0.2),
        prompt: "Generate complete production-ready XCTest Swift code for testing Face ID authentication on iOS. Include happy path, edge cases, negative tests, and accessibility tests."),
    QuickCommand(title: "Convert Requirement", subtitle: "English to XCTest", icon: "text.badge.checkmark", color: .teal,
        prompt: "Convert this plain English requirement to complete XCTest Swift code: Users should be able to log in with Face ID and fall back to password if Face ID fails.")
]

// MARK: - AI Service

class AIService: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var statusText = ""
    @Published var macIPAddress = UserDefaults.standard.string(forKey: "macIPAddress") ?? ""

    var ollamaURL: String {
        "http://\(macIPAddress):11434/api/chat"
    }

    func sendMessage(_ content: String) async {
        let userMessage = Message(role: "user", content: content)
        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
            statusText = "AIdria is thinking…"
        }

        let systemPrompt = """
        You are AIdria, an elite Apple QA engineering AI assistant built by Deandre Medrano.
        You specialize in Apple QA engineering, test planning, accessibility auditing, defect prediction,
        XCTest automation, and Apple Feedback Assistant report writing.
        You are helpful, concise, and professional. You think like a senior Apple QA engineer.
        Current user: Deandre Medrano — preparing for Apple QA engineering roles.
        """

        let requestMessages = [OllamaMessage(role: "system", content: systemPrompt)] +
            messages.map { OllamaMessage(role: $0.role, content: $0.content) }

        let request = OllamaRequest(
            model: "mistral-nemo:latest",
            messages: requestMessages,
            stream: false
        )

        guard let url = URL(string: ollamaURL) else {
            await MainActor.run {
                messages.append(Message(role: "assistant", content: "Invalid Mac IP address. Please update it in Settings."))
                isLoading = false
                statusText = ""
            }
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
            let reply = Message(role: "assistant", content: response.message.content)
            await MainActor.run {
                messages.append(reply)
                isLoading = false
                statusText = ""
            }
        } catch {
            await MainActor.run {
                messages.append(Message(role: "assistant", content: "Connection error. Make sure your Mac is on the same WiFi and Ollama is running.\n\nError: \(error.localizedDescription)"))
                isLoading = false
                statusText = ""
            }
        }
    }

    func clearMessages() {
        messages = []
    }

    func saveMacIP(_ ip: String) {
        macIPAddress = ip
        UserDefaults.standard.set(ip, forKey: "macIPAddress")
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var aiService = AIService()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(aiService: aiService, selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            ChatView(aiService: aiService)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(1)

            SettingsView(aiService: aiService)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Home View

struct HomeView: View {
    @ObservedObject var aiService: AIService
    @Binding var selectedTab: Int
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AIdria")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("Apple QA Command Center")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Text("◎")
                                    .font(.system(size: 24))
                            }
                        }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(aiService.macIPAddress.isEmpty ? Color.red : Color.green)
                                .frame(width: 7, height: 7)
                            Text(aiService.macIPAddress.isEmpty ? "Not connected — add Mac IP in Settings" : "Connected to \(aiService.macIPAddress)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

                    Text("Quick Commands")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 4)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(quickCommands) { cmd in
                            QuickCommandCard(command: cmd) {
                                Task {
                                    selectedTab = 1
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    await aiService.sendMessage(cmd.prompt)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Feedback Portfolio")
                            .font(.headline)
                        Text("Use AIdria to find real bugs in Apple apps and generate professional Feedback Assistant reports. Submit at feedbackassistant.apple.com to build your portfolio.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                        Link("Open Feedback Assistant →", destination: URL(string: "https://feedbackassistant.apple.com")!)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.06))
                    .cornerRadius(12)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Quick Command Card

struct QuickCommandCard: View {
    let command: QuickCommand
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(command.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: command.icon)
                        .font(.system(size: 18))
                        .foregroundColor(command.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(command.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(command.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Chat View

struct ChatView: View {
    @ObservedObject var aiService: AIService
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if aiService.messages.isEmpty {
                                VStack(spacing: 16) {
                                    Text("◎")
                                        .font(.system(size: 48))
                                        .opacity(0.3)
                                    Text("AIdria Mobile")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Your Apple QA AI assistant.\nAsk anything or use Quick Commands.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            }

                            ForEach(aiService.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if aiService.isLoading {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .id("loading")
                            }
                        }
                        .padding(.vertical, 12)
                        .onChange(of: aiService.messages.count) { _ in
                            if let last = aiService.messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: aiService.isLoading) { _ in
                            if aiService.isLoading {
                                withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                            }
                        }
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    TextField("Ask AIdria anything…", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .lineLimit(1...4)
                        .focused($inputFocused)

                    Button {
                        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        let text = inputText
                        inputText = ""
                        Task { await aiService.sendMessage(text) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isLoading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
            .navigationTitle("AIdria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        aiService.clearMessages()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    @State private var copied = false

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "You" : "AIdria")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                Text(message.content)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.blue : Color(.systemGray6))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(18)
                    .onLongPressGesture {
                        UIPasteboard.general.string = message.content
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }

                if copied {
                    Text("Copied!")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }

            if !isUser { Spacer(minLength: 48) }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1.3 : 0.7)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animating)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(18)
        .onAppear { animating = true }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var aiService: AIService
    @State private var ipInput = ""
    @State private var saved = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mac IP Address")
                            .font(.headline)
                        Text("Enter your Mac's local IP address so AIdria Mobile can connect to Ollama running on your Mac over WiFi.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g. 192.168.1.100", text: $ipInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                        Button("Save Connection") {
                            aiService.saveMacIP(ipInput)
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                        }
                        .buttonStyle(.borderedProminent)
                        if saved {
                            Text("✓ Saved!")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Connection")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How to find your Mac's IP")
                            .font(.headline)
                        Text("1. On your Mac, open System Settings")
                        Text("2. Go to Wi-Fi")
                        Text("3. Click Details next to your network")
                        Text("4. Copy the IP Address (e.g. 192.168.1.100)")
                        Text("5. Make sure your iPhone and Mac are on the same WiFi network")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                } header: {
                    Text("Setup Guide")
                }

                Section {
                    HStack {
                        Text("Model")
                        Spacer()
                        Text("Mistral Nemo 12B")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Privacy")
                        Spacer()
                        Text("100% Local")
                            .foregroundColor(.green)
                    }
                    HStack {
                        Text("Cloud")
                        Spacer()
                        Text("None")
                            .foregroundColor(.green)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }

                Section {
                    Link("Feedback Assistant", destination: URL(string: "https://feedbackassistant.apple.com")!)
                    Link("GitHub Portfolio", destination: URL(string: "https://github.com/deandremedrano")!)
                } header: {
                    Text("Links")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                ipInput = aiService.macIPAddress
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
