import SwiftUI

@Observable
final class AppState {
    var authService = AuthService()
    var taskService = TaskService()
    var locationService = LocationService()
    var storageService = StorageService()
    var messageService = MessageService()
    var inspectionService = InspectionService()
    var pushService = PushNotificationService()

    // Onboarding
    var needsOnboarding = false
    var onboardingRole: UserRole = .agent
    var draftTaskFromOnboarding: UUID?

    // Navigation
    var selectedTab: AppTab = .dashboard
    var dashboardPath = NavigationPath()
    var notificationsPath = NavigationPath()
    var profilePath = NavigationPath()

    // Deep linking
    func deepLink(tab: AppTab, destination: any Hashable) {
        selectedTab = tab
        switch tab {
        case .dashboard:
            dashboardPath.append(destination)
        case .notifications:
            notificationsPath.append(destination)
        case .profile:
            profilePath.append(destination)
        }
    }

    func popToRoot(tab: AppTab) {
        switch tab {
        case .dashboard:
            dashboardPath = NavigationPath()
        case .notifications:
            notificationsPath = NavigationPath()
        case .profile:
            profilePath = NavigationPath()
        }
    }
}

enum AppTab: Hashable {
    case dashboard
    case notifications
    case profile
}

// MARK: - Navigation Destinations

enum DashboardDestination: Hashable {
    case taskDetail(UUID)
    case filteredList(TaskStatus)
    case allTasks
    case messaging(taskId: UUID, otherUserName: String)
    case directMessaging(conversationId: UUID, otherUserName: String)
    case publicProfile(UUID)
    case publicProfileBySlug(String)
    case inspectionChecklist(UUID)
    case inspectionReport(UUID)
}

enum NotificationDestination: Hashable {
    case settings
}

enum ProfileDestination: Hashable {
    case verification
    case personalInfo
    case paymentMethods
    case payoutSettings
    case notificationSettings
    case taskHistory
    case earnings
    case serviceAreas
    case availability
    case accountSecurity
    case publicProfile
}
