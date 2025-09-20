//
//  Auth.swift
//  HXGNYV1
//
//  Created by Chen Feng on 9/8/25.
//

// Store/AuthStore.swift
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CryptoKit
import AuthenticationServices

@MainActor
final class AuthStore: ObservableObject {
    @Published var user: User?            // FirebaseAuth.User
    @Published var profile: [String:Any]? // Firestore user doc

    private var currentNonce: String?
    private let db = Firestore.firestore()

    init() {
        self.user = Auth.auth().currentUser
        Task { await loadProfile() }
        // Listen for changes
        Auth.auth().addStateDidChangeListener { _, user in
            Task { @MainActor in
                self.user = user
                await self.loadProfile()
            }
        }
    }

    // --------- Guest (anonymous) ----------
    func signInAnonymously() async throws {
        let result = try await Auth.auth().signInAnonymously()
        try await ensureUserDoc(uid: result.user.uid, displayName: "Guest")
    }

    // --------- Sign in with Apple ----------
    func startSignInWithApple() -> ASAuthorizationController {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        return controller
    }

    func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async throws {
        guard let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else { throw NSError(domain: "Auth", code: -1) }

        let firebaseCred = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        let result = try await Auth.auth().signIn(with: firebaseCred)
        let name = credential.fullName?.formatted(.name(style: .medium))
                 ?? result.user.displayName
                 ?? "Apple User"
        try await ensureUserDoc(uid: result.user.uid, displayName: name, email: result.user.email)
    }

    // --------- Sign out ----------
    func signOut(schedule: ScheduleStore? = nil) {
        try? Auth.auth().signOut()
        schedule?.clear()
    }

    // --------- Firestore user doc ----------
    private func ensureUserDoc(uid: String, displayName: String?, email: String? = nil) async throws {
        let ref = db.collection("users").document(uid)
        let snapshot = try await ref.getDocument()
        if snapshot.exists { return }
        try await ref.setData([
            "displayName": displayName ?? "",
            "email": email ?? "",
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    private func loadProfile() async {
        guard let uid = user?.uid else { profile = nil; return }
        let ref = db.collection("users").document(uid)
        if let snap = try? await ref.getDocument(), snap.exists {
            profile = snap.data()
        }
    }

    // MARK: - Nonce helpers
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    private func randomNonceString(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""; result.reserveCapacity(length)
        for _ in 0..<length { result.append(chars.randomElement()!) }
        return result
    }
    
    func makeAppleController() -> (ASAuthorizationController, AppleAuthDelegate) {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleAuthDelegate(auth: self)
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        return (controller, delegate)
    }
}

import FirebaseAuth

@MainActor
extension AuthStore {
    // Sign in (links if the current user is anonymous so you keep their data)
    func signIn(email: String, password: String) async throws {
        if let current = Auth.auth().currentUser, current.isAnonymous {
            let cred = EmailAuthProvider.credential(withEmail: email, password: password)
            let result = try await current.link(with: cred)
            try await postSignInSetup(user: result.user, displayName: result.user.displayName)
        } else {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            try await postSignInSetup(user: result.user, displayName: result.user.displayName)
        }
    }

    // Create account (links to anon user if present)
    func signUp(email: String, password: String, displayName: String?) async throws {
        if let current = Auth.auth().currentUser, current.isAnonymous {
            let cred = EmailAuthProvider.credential(withEmail: email, password: password)
            let result = try await current.link(with: cred)
            if let displayName { try await updateDisplayName(result.user, displayName: displayName) }
            try await postSignInSetup(user: result.user, displayName: displayName)
        } else {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            if let displayName { try await updateDisplayName(result.user, displayName: displayName) }
            try await postSignInSetup(user: result.user, displayName: displayName)
        }
    }

    func sendPasswordReset(to email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Helpers
    private func updateDisplayName(_ user: FirebaseAuth.User, displayName: String) async throws {
        let change = user.createProfileChangeRequest()
        change.displayName = displayName
        try await change.commitChanges()
    }

    private func postSignInSetup(user: FirebaseAuth.User, displayName: String?) async throws {
        try await ensureUserDoc(uid: user.uid,
                                displayName: displayName ?? user.displayName ?? "User",
                                email: user.email)
        await MainActor.run { self.user = user }
        await loadProfile()
    }
}

import SwiftUI

struct EmailAuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthStore

    enum Mode { case signIn, signUp, reset }
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    Text("Sign In").tag(Mode.signIn)
                    Text("Create").tag(Mode.signUp)
                    Text("Reset").tag(Mode.reset)
                }
                .pickerStyle(.segmented)

                Section {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    if mode != .reset {
                        SecureField("Password (min 6)", text: $password)
                            .textContentType(.password)
                    }
                    if mode == .signUp {
                        TextField("Display Name (optional)", text: $displayName)
                    }
                }

                if let e = error {
                    Text(e).foregroundColor(.red).font(.footnote)
                }
            }
            .navigationTitle("Email Sign In")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionTitle) { Task { await runAction() } }
                        .disabled(isDisabled)
                }
            }
        }
    }

    private var actionTitle: String {
        switch mode { case .signIn: "Sign In"; case .signUp: "Create"; case .reset: "Send Link" }
    }
    private var isDisabled: Bool {
        switch mode { case .signIn, .signUp: email.isEmpty || password.count < 6
                      case .reset: email.isEmpty }
    }

    private func runAction() async {
        do {
            switch mode {
            case .signIn:
                try await auth.signIn(email: email, password: password)
                dismiss()
            case .signUp:
                try await auth.signUp(email: email, password: password,
                                      displayName: displayName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : displayName)
                dismiss()
            case .reset:
                try await auth.sendPasswordReset(to: email)
                error = "Reset email sent."
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
// Views/ProfileMenuButton.swift (new)
import SwiftUI
import AuthenticationServices

struct ProfileMenuButton: View {
    @EnvironmentObject var auth: AuthStore
    @State private var showEmailSheet = false
    @EnvironmentObject var schedule: ScheduleStore
    var body: some View {
        Menu {
            if let user = auth.user {
                // Signed in
                if let name = auth.profile?["displayName"] as? String {
                    Label(name, systemImage: "person.crop.circle")
                }
                if let email = auth.profile?["email"] as? String {
                    Text(email).font(.caption).foregroundColor(.secondary)
                }
                Divider()
                Button(role: .destructive) {
                    auth.signOut(schedule: schedule)
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .environmentObject(schedule)
            } else {
                // Not signed in
//                Button {
//                    Task { try? await auth.signInAnonymously() }
//                } label: {
//                    Label("Continue as Guest", systemImage: "person.badge.clock")
//                }
                

                // inside Menu (when not signed in):
                Button {
                    showEmailSheet = true
                } label: {
                    Label("Sign in with Email", systemImage: "envelope")
                }
                .sheet(isPresented: $showEmailSheet) {
                    EmailAuthSheet().environmentObject(auth)
                }
                SignInWithAppleRow()
            }
        } label: {
            Image(systemName: auth.user == nil
                  ? "person.crop.circle.badge.plus" // not signed in
                  : "person.crop.circle.fill")      // signed in
                .imageScale(.large)
        }
        .sheet(isPresented: $showEmailSheet) {    // ⬅️ attach at top level
                    EmailAuthSheet().environmentObject(auth)
                }
        .accessibilityLabel(auth.user == nil ? "Sign In" : "Profile")
    }
}

// Views/ProfileMenuButton.swift (or SignInWithAppleRow)
import AuthenticationServices
import SwiftUI

struct SignInWithAppleRow: View {
    @EnvironmentObject var auth: AuthStore
    @State private var controller: ASAuthorizationController?
    @State private var delegateRef: AppleAuthDelegate?   // keep a strong reference

    var body: some View {
        Button {
            let (c, d) = auth.makeAppleController()
            controller = c
            delegateRef = d
            c.performRequests()
        } label: {
            Label("Sign in with Apple", systemImage: "apple.logo")
        }
    }
}


// UIKit-style delegate to bridge ASAuthorizationController -> Firebase
final class AppleAuthDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let auth: AuthStore
    init(auth: AuthStore) { self.auth = auth }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            if let appleID = authorization.credential as? ASAuthorizationAppleIDCredential {
                try? await auth.handleAppleCredential(appleID)
            }
        }
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple sign-in failed:", error)
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? UIWindow()
    }
}
