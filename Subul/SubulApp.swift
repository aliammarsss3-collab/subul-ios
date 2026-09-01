import SwiftUI
import CryptoKit

@main
struct SubulApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.currentUser == nil {
                    LoginView()
                } else {
                    HomeView()
                }
            }
            .environmentObject(session)
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.light)
        }
    }
}

final class SessionStore: ObservableObject {
    @Published var currentUser: String?
    @Published var loginError = false

    func login(username: String, password: String) {
        let digest = SHA256.hash(data: Data(password.utf8)).map { String(format: "%02x", $0) }.joined()
        let valid = (username == "admin" && digest == "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918") ||
                    (username == "admin1" && digest == "25f43b1486ad95a1398e3eeb3d83bc4010015fcc9bedb35b432e00298d5021f7")
        loginError = !valid
        if valid { currentUser = username }
    }

    func logout() { currentUser = nil }
}

struct LoginView: View {
    @EnvironmentObject var session: SessionStore
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.indigo.opacity(0.9), Color.cyan.opacity(0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                Text("سُبُل")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("رسائلك واتصالاتك في مكان واحد")
                    .foregroundStyle(.white.opacity(0.9))

                VStack(spacing: 14) {
                    TextField("اسم المستخدم", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    SecureField("كلمة المرور", text: $password)
                        .textFieldStyle(.roundedBorder)
                    if session.loginError {
                        Text("اسم المستخدم أو كلمة المرور غير صحيحة")
                            .font(.footnote).foregroundStyle(.red)
                    }
                    Button("تسجيل الدخول") {
                        session.login(username: username.trimmingCharacters(in: .whitespaces), password: password)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            }
            .padding(28)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var session: SessionStore
    @State private var search = ""

    private var otherUser: String { session.currentUser == "admin" ? "admin1" : "admin" }

    var body: some View {
        NavigationStack {
            List {
                Section("الأشخاص") {
                    if search.isEmpty || otherUser.localizedCaseInsensitiveContains(search) {
                        NavigationLink {
                            ChatView(me: session.currentUser ?? "", other: otherUser)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Color.indigo.gradient).frame(width: 50, height: 50)
                                    Text(String(otherUser.prefix(1)).uppercased())
                                        .font(.title2.bold()).foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(otherUser).font(.headline)
                                    Text("اضغط للمراسلة أو الاتصال").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "ابحث عن شخص")
            .navigationTitle("سُبُل")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("خروج") { session.logout() }
                }
            }
        }
    }
}

