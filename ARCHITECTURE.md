# Architecture - ProductivityHub

The app follows a modern, scalable approach combining **Clean Architecture**, **MVVM**, and the **Coordinator** pattern.

## 🏗 High-Level Design

### Layers

1.  **🚀 Presentation (UI)**
    *   **SwiftUI Views**: High-level components and screens.
    *   **ViewModels**: State-driven logic for each feature.
    *   **Coordinators**: Manage navigation flow and tab transitions.

2.  **🧠 Domain (Core Business Logic)**
    *   **Models**: Plain Swift classes representing Tasks, Notes, and Events.
    *   **Repository Protocols**: Abstract definitions for data interaction.
    *   **Services**: Shared utilities like Notifications and Search.

3.  **💾 Data (Persistence)**
    *   **SwiftData Repositories**: Concrete implementations of the domain protocols.
    *   **Compatibility Layer**: Stubs to support Xcode 14 and Swift 5.8 compilers.

## 🛠 Dependency Injection

A centralized `DependencyContainer` handles the instantiation and lifetime of all services and repositories. It ensures that components remain loosely coupled and easily testable.

## 🔄 Data Flow

1.  **User Interaction**: A View triggers an action on the ViewModel.
2.  **Repository Call**: The ViewModel calls a repository to fetch or update data.
3.  **State Update**: The ViewModel updates its internal `@Published` state based on the result.
4.  **UI Refresh**: SwiftUI automatically re-renders the View in response to state changes.

## 🧪 Testing

The project is structured to support comprehensive testing:
- **Unit Tests**: Business logic in ViewModels.
- **Integration Tests**: Repository-to-Model interactions.
- **UI Tests**: Interaction flows using SwiftUI previews and automated tests.
