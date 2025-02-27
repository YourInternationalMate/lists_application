# Modern Lists App

A feature-rich Flutter application for managing lists with real-time synchronization, multi-currency support, and a modern user interface.

![Flutter Version](https://img.shields.io/badge/Flutter-3.5.3-blue.svg)
![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ Features

- **Multiple Lists**: Create and manage multiple lists
- **Real-time Sync**: All changes are synchronized in real-time using Firebase
- **Multi-Currency Support**: Toggle between EUR (€) and USD ($) with automatic conversion
- **Category Filtering**: Organize items by categories for better overview
- **Drag & Drop**: Intuitive drag-and-drop reordering of items
- **Share Lists**: Collaborate by sharing lists with other users
- **Dark/Light Theme**: Automatic theme switching based on system preferences
- **Animated UI**: Smooth animations and transitions throughout the app
- **URL Support**: Add and open product URLs directly from items
- **Offline Support**: Local caching for offline access

## 🚀 Getting Started

### Prerequisites

- Flutter (3.5.3 or higher)
- Dart SDK
- Firebase account
- Android Studio / VS Code

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/shopping-lists-app.git
```

2. Install dependencies
```bash
flutter pub get
```

3. Configure Firebase
   - Create a new Firebase project
   - Add Android & iOS apps in Firebase console
   - Download and replace the `google-services.json` and `GoogleService-Info.plist`
   - Enable Email/Password authentication in Firebase console
   - Set up Cloud Firestore database

4. Run the app
```bash
flutter run
```

## 🏗️ Architecture

The app follows a clean architecture pattern with:

- **Firebase Service**: Handles all Firebase interactions
- **Local Database**: Manages local caching and offline support
- **UI Components**: Reusable widgets with consistent styling
- **State Management**: Stream-based real-time updates
- **Animations**: Custom animation controllers for smooth transitions

## 🛠️ Built With

- **Flutter**: UI framework
- **Firebase**:
  - Authentication
  - Cloud Firestore
  - Real-time Database
- **Provider**: State management
- **flutter_slidable**: Sliding actions
- **url_launcher**: External URL handling

## 📱 Screenshots

Screenshots coming soon

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

- GitHub: [@YourInternationalMate](https://github.com/YourInternationalMate)

## 🙏 Acknowledgments

- [Flutter Team](https://flutter.dev)
- [Firebase](https://firebase.google.com)
- All contributors who help improve this project
