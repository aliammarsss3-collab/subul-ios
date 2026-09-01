import SwiftUI
import UIKit

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let sender: String
    let recipient: String
    let text: String
    let timestamp: Double
}

@MainActor
final class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    private let topic = "subul-aliammar-7e29c1a4"
    private var pollingTask: Task<Void, Never>?

    func start(me: String, other: String) {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await fetch(me: me, other: other)
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stop() { pollingTask?.cancel() }

    func send(text: String, from sender: String, to recipient: String) async {
        let message = ChatMessage(id: UUID().uuidString, sender: sender, recipient: recipient,
                                  text: text, timestamp: Date().timeIntervalSince1970)
        guard let body = try? JSONEncoder().encode(message),
              let url = URL(string: "https://ntfy.sh/\(topic)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.base64EncodedData()
        request.setValue("base64", forHTTPHeaderField: "Encoding")
        request.setValue("رسالة سُبُل", forHTTPHeaderField: "Title")
        _ = try? await URLSession.shared.data(for: request)
        await fetch(me: sender, other: recipient)
    }

    private func fetch(me: String, other: String) async {
        guard let url = URL(string: "https://ntfy.sh/\(topic)/json?poll=1&since=all") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let raw = String(data: data, encoding: .utf8) else { return }

        let decoded = raw.split(separator: "\n").compactMap { line -> ChatMessage? in
            guard let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let encoded = json["message"] as? String,
                  let body = Data(base64Encoded: encoded),
                  let item = try? JSONDecoder().decode(ChatMessage.self, from: body) else { return nil }
            return item
        }
        messages = decoded.filter {
            ($0.sender == me && $0.recipient == other) || ($0.sender == other && $0.recipient == me)
        }.sorted { $0.timestamp < $1.timestamp }
    }
}

struct ChatView: View {
    let me: String
    let other: String
    @StateObject private var service = ChatService()
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(service.messages) { message in
                            HStack {
                                if message.sender == me { Spacer(minLength: 50) }
                                Text(message.text)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(message.sender == me ? Color.indigo : Color(.secondarySystemBackground),
                                                in: RoundedRectangle(cornerRadius: 16))
                                    .foregroundStyle(message.sender == me ? .white : .primary)
                                if message.sender != me { Spacer(minLength: 50) }
                            }
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: service.messages.count) { _ in
                    if let last = service.messages.last { withAnimation { proxy.scrollTo(last.id) } }
                }
            }

            HStack(spacing: 10) {
                TextField("اكتب رسالة…", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty else { return }
                    draft = ""
                    Task { await service.send(text: value, from: me, to: other) }
                } label: { Image(systemName: "paperplane.fill") }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle(other)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { openCall(video: false) } label: { Image(systemName: "phone.fill") }
                Button { openCall(video: true) } label: { Image(systemName: "video.fill") }
            }
        }
        .task { service.start(me: me, other: other) }
        .onDisappear { service.stop() }
    }

    private func openCall(video: Bool) {
        let mode = video ? "video" : "audio"
        let room = "SubulAliammar7e29c1a4-\(mode)"
        if let url = URL(string: "https://meet.jit.si/\(room)") {
            UIApplication.shared.open(url)
        }
    }
}


