import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase

@MainActor
final class AuthManager: ObservableObject {
    @Published var user: User?
    @Published var session: Session?
    @Published var isLoading = true
    @Published var error: String?
    @Published var appleFullName: String?

    private var authStateTask: Task<Void, Never>?

    func initialize() async {
        isLoading = true
        defer { isLoading = false }

        do {
            session = try await Config.supabase.auth.session
            user = session?.user
        } catch {
            // No existing session — user needs to sign in
            self.user = nil
            self.session = nil
        }

        listenForAuthChanges()
    }

    private func listenForAuthChanges() {
        authStateTask?.cancel()
        authStateTask = Task {
            for await (event, session) in Config.supabase.auth.authStateChanges {
                guard !Task.isCancelled else { return }
                self.session = session
                self.user = session?.user

                if event == .signedOut {
                    self.session = nil
                    self.user = nil
                }
            }
        }
    }

    // MARK: - Apple Sign-In

    func signInWithApple() {
        let nonce = randomNonceString()
        let hashedNonce = sha256(nonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let delegate = AppleSignInDelegate(nonce: nonce) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let (idToken, fullName)):
                    self?.appleFullName = fullName
                    await self?.handleAppleToken(idToken: idToken, nonce: nonce, fullName: fullName)
                case .failure(let err):
                    self?.error = err.localizedDescription
                }
            }
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate

        // Retain the delegate for the lifetime of the request
        objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

        controller.performRequests()
    }

    private func handleAppleToken(idToken: String, nonce: String, fullName: String? = nil) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await Config.supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            self.session = session
            self.user = session.user

            // Save full name to user metadata if Apple provided it
            if let name = fullName, !name.isEmpty {
                try? await Config.supabase.auth.update(user: UserAttributes(data: ["full_name": .string(name)]))
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Email Sign-In (Dev)

    func signInWithEmail(_ email: String, password: String) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await Config.supabase.auth.signIn(
                email: email,
                password: password
            )
            self.session = session
            self.user = session.user
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await Config.supabase.auth.signOut()
            session = nil
            user = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Apple Sign-In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let nonce: String
    let completion: (Result<(String, String?), Error>) -> Void

    init(nonce: String, completion: @escaping (Result<(String, String?), Error>) -> Void) {
        self.nonce = nonce
        self.completion = completion
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            completion(.failure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])))
            return
        }

        var fullName: String?
        if let nameComponents = appleIDCredential.fullName {
            let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
            if !parts.isEmpty { fullName = parts.joined(separator: " ") }
        }

        completion(.success((idTokenString, fullName)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Don't surface cancellation as an error
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return
        }
        completion(.failure(error))
    }
}
