import SwiftUI
import Supabase

/// Resolves a profile slug to a user ID and renders the existing PublicProfileReadOnlyView.
/// Used for universal links: /agent/{slug}
struct PublicProfileBySlugView: View {
    let slug: String

    @State private var resolvedUserId: UUID?
    @State private var notFound = false

    var body: some View {
        Group {
            if let userId = resolvedUserId {
                PublicProfileReadOnlyView(userId: userId)
            } else if notFound {
                ContentUnavailableView(
                    "Profile Not Found",
                    systemImage: "person.slash",
                    description: Text("This profile doesn't exist or isn't public.")
                )
            } else {
                ProgressView("Loading profile...")
            }
        }
        .task {
            await resolveSlug()
        }
    }

    private func resolveSlug() async {
        do {
            struct SlugResult: Decodable {
                let id: UUID
            }
            let result: SlugResult = try await supabase
                .from("public_profiles")
                .select("id")
                .eq("profile_slug", value: slug)
                .eq("is_public_profile_enabled", value: true)
                .single()
                .execute()
                .value

            await MainActor.run {
                resolvedUserId = result.id
            }
        } catch {
            await MainActor.run {
                notFound = true
            }
        }
    }
}
