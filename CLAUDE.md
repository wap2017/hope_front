# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is "心灵伴侣" (Soulmate), a Flutter mental health/emotional support application with multi-platform support. The app uses a traditional StatefulWidget architecture with `SharedPreferences` for local storage and token-based authentication.

## Development Commands

### Setup and Dependencies
```bash
flutter pub get
flutter pub upgrade
```

### Running the App
```bash
flutter run                    # Default device
flutter run -d chrome          # Web development
flutter run -d android         # Android device/emulator
flutter run -d ios            # iOS simulator/device
```

### Building
```bash
flutter build apk             # Android APK
flutter build ios             # iOS build
flutter build web             # Web build
```

### Code Quality
```bash
flutter test                   # Run tests
flutter analyze               # Static analysis
```

### Custom Commands
```bash
./install_icons.sh /path/to/project    # Install custom Android icons
```

## Architecture Overview

### Navigation Structure
The app uses a single-page `BottomNavigationBar` architecture with 4 main sections:
1. **Chat** (`ChatPage`) - AI/messaging interface
2. **Posts** (`PostSquarePage`) - Social sharing platform
3. **Notes** (`NotePage`) - Personal journaling with custom HTTP client
4. **Settings** (`SettingsPage`) - User preferences

### Key Files and Entry Points
- `lib/main.dart` - App entry point, theme configuration, and routing setup
- `lib/home.dart` - Main navigation, authentication wrapper, and login flow
- `lib/api_error_handler.dart` - Centralized error handling for all API calls
- `lib/user_profile_service.dart` - User data management and authentication

### API Integration
- **Base URL**: `https://hope.layu.cc/hope`
- **Pattern**: Direct HTTP calls in UI components using `http` package
- **Authentication**: Token-based with automatic logout on 401 errors
- **Error Handling**: Always use `ApiErrorHandler` patterns for consistency

### State Management
- Uses traditional StatefulWidget with `setState()`
- No external state management libraries (Provider, Bloc, etc.)
- Local persistence via `SharedPreferences`
- Authentication state managed through `UserProfileService`

### UI Design System
The app follows a healing/therapy aesthetic with:
- **Colors**: Defined in `main.dart` as `AppColors` (soft pink/green palette)
- **Typography**: SF Pro Display font family
- **Layout**: `AppDimens` for consistent spacing
- **Theme**: `AppTheme` class for centralized styling

### Code Organization
- **Single responsibility**: Each file handles one main feature (chat, posts, notes, settings)
- **Direct API calls**: HTTP requests are made directly in UI components
- **Mixed concerns**: Business logic and UI are not strictly separated
- **Chinese language**: UI text primarily in Chinese for Chinese-speaking users

## Development Guidelines

### When Adding New Features
1. Follow existing patterns in similar feature files (chat.dart, post.dart, etc.)
2. Use `AppColors`, `AppDimens`, and `AppTheme` for consistent styling
3. Implement error handling using `ApiErrorHandler` patterns
4. Use `UserProfileService` for any authentication-related operations
5. Follow the existing StatefulWidget + setState pattern

### Testing
Current test coverage is minimal. When adding tests, start with widget tests following the pattern in `test/widget_test.dart`.

### Platform-Specific Considerations
The app supports Android, iOS, Web, Windows, Linux, and macOS. Use the custom icon installation script for Android development.