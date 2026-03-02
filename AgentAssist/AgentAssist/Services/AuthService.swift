import Foundation
import Supabase

@Observable
final class AuthService {
    var currentSession: Session?
    var currentUser: AppUser?
    var isLoading = true

    init() {
        Task { await initialize() }
    }

    var isAuthenticated: Bool {
        currentSession != nil && currentUser != nil
    }

    func initialize() async {
        do {
            currentSession = try await supabase.auth.session
            if let session = currentSession {
                await fetchUserProfile(userId: session.user.id)
            }
        } catch {
            currentSession = nil
            currentUser = nil
        }
        isLoading = false
    }

    func signUp(email: String, password: String, fullName: String, phone: String, role: UserRole) async throws {
        let authResponse = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: [
                "full_name": .string(fullName),
                "role": .string(role.rawValue),
                "phone": .string(phone),
            ]
        )

        // Create user profile in public.users (upsert to handle retries gracefully)
        let userId = authResponse.session?.user.id ?? authResponse.user.id
        try await supabase.from("users").upsert([
            "id": userId.uuidString,
            "role": role.rawValue,
            "email": email,
            "full_name": fullName,
            "phone": phone,
        ]).execute()

        // If email confirmation is disabled, we get a session immediately
        if let session = authResponse.session {
            currentSession = session
            await fetchUserProfile(userId: session.user.id)
        }
    }

    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        currentSession = session
        await fetchOrCreateProfile(session: session)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        currentSession = nil
        currentUser = nil
    }

    func fetchUserProfile(userId: UUID) async {
        do {
            let users: [AppUser] = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            currentUser = users.first
        } catch {
            print("[AuthService] Failed to fetch user profile: \(error)")
        }
    }

    /// Fetches the profile, or auto-creates it from auth metadata if missing
    /// (handles the case where signup's profile insert failed)
    private func fetchOrCreateProfile(session: Session) async {
        await fetchUserProfile(userId: session.user.id)

        // Profile exists — done
        if currentUser != nil { return }

        // No profile row — try to recover from auth metadata
        let metadata = session.user.userMetadata

        func string(from anyJSON: AnyJSON?) -> String? {
            guard let anyJSON else { return nil }
            switch anyJSON {
            case .string(let s):
                return s
            case .bool(let b):
                return String(b)
            case .null:
                return nil
            case .array, .object:
                // Not expected for these fields; ignore complex types
                return nil
            @unknown default:
                // For any future scalar cases (e.g., numeric variants), fall back to description
                return String(describing: anyJSON)
            }
        }

        let fullName = string(from: metadata["full_name"]) ??
            session.user.email?.components(separatedBy: "@").first ??
            "User"
        let role = string(from: metadata["role"]) ?? "agent"
        let phone = string(from: metadata["phone"]) ?? ""

        do {
            try await supabase.from("users").upsert([
                "id": session.user.id.uuidString,
                "role": role,
                "email": session.user.email ?? "",
                "full_name": fullName,
                "phone": phone,
            ]).execute()
            print("[AuthService] Auto-created missing profile for \(session.user.id)")
            await fetchUserProfile(userId: session.user.id)
        } catch {
            print("[AuthService] Failed to auto-create profile: \(error)")
        }
    }

    func listenForAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn:
                currentSession = session
                if let session {
                    await fetchOrCreateProfile(session: session)
                }
            case .signedOut:
                currentSession = nil
                currentUser = nil
            default:
                break
            }
        }
    }
}
