import SwiftUI
import AuthenticationServices

struct LoginView: View {

    @State private var supabase = SupabaseService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Used to compute a fresh nonce for each Sign In with Apple request.
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App identity
            VStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.red)
                Text("HealthOS")
                    .font(.largeTitle.bold())
                Text("Your AI health coach")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Sign In with Apple
            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonce()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal)

            // Dev-only email/password fallback
            #if DEBUG
            DevLoginView()
                .padding(.horizontal)
            #endif

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView()
                    .controlSize(.large)
            }
        }
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(
        _ result: Result<ASAuthorization, Error>
    ) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Sign in failed: invalid Apple credential."
                return
            }
            Task { await signInWithApple(idToken: idToken, nonce: nonce) }

        case .failure(let error):
            let nsError = error as NSError
            // ASAuthorizationErrorCanceled = 1001 — user dismissed, no need to show error.
            if nsError.code != 1001 {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signInWithApple(idToken: String, nonce: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await supabase.signInWithApple(idToken: idToken, nonce: nonce)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Dev Login (DEBUG only)

#if DEBUG
private struct DevLoginView: View {

    @State private var supabase = SupabaseService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            Divider()
            Text("Dev Login")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Button("Sign In") {
                    Task { await devSignIn() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || email.isEmpty || password.isEmpty)

                Button("Sign Up") {
                    Task { await devSignUp() }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .disabled(isLoading)
    }

    private func devSignIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await supabase.signInWithEmail(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func devSignUp() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await supabase.signUpWithEmail(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif

// MARK: - Crypto Helpers for Sign In with Apple nonce

import CryptoKit

private func randomNonce(length: Int = 32) -> String {
    var randomBytes = [UInt8](repeating: 0, count: length)
    _ = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
    return randomBytes.map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ input: String) -> String {
    let hash = SHA256.hash(data: Data(input.utf8))
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}
