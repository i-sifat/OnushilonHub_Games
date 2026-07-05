<p align="center">
  <img src="https://github.com/i-sifat/OnushilonHub_Games/blob/main/assets/images/icon-192.png?raw=true" width="120" alt="OnushilonHub Logo">
</p>

<h1 align="center">OnushilonHub Games</h1>

<p align="center">
  <b>Interactive Learning Through Play</b><br>
  A curated collection of educational games designed to make learning engaging, accessible, and fun for everyone.
</p>

<p align="center">
  <a href="https://github.com/i-sifat/OnushilonHub_Games/actions/workflows/build-release.yml">
    <img src="https://github.com/i-sifat/OnushilonHub_Games/actions/workflows/build-release.yml/badge.svg" alt="Build Status">
  </a>
  <a href="https://github.com/i-sifat/OnushilonHub_Games/releases/latest">
    <img src="https://img.shields.io/github/v/release/i-sifat/OnushilonHub_Games?include_prereleases&sort=semver" alt="Latest Release">
  </a>
  <a href="https://github.com/i-sifat/OnushilonHub_Games/releases">
    <img src="https://img.shields.io/github/downloads/i-sifat/OnushilonHub_Games/total" alt="Downloads">
  </a>
  <img src="https://img.shields.io/badge/Platform-Android-green?logo=android" alt="Platform">
  <img src="https://img.shields.io/badge/Built%20with-Flutter-blue?logo=flutter" alt="Flutter">
</p>

---

## 📱 About

**OnushilonHub Games** (*Onushilon* = Learning/Education) is a Flutter-based Android application that brings together a collection of interactive educational games. Built with a focus on accessibility and engagement, the app aims to transform traditional learning into an enjoyable experience through gamification.

Whether you're a student looking to reinforce concepts, a teacher seeking classroom tools, or a parent wanting productive screen time for your children — OnushilonHub provides a seamless, ad-free learning environment.

---

## ✨ Features

- 🎮 **Curated Game Collection** — Handpicked educational games covering multiple subjects and skill levels
- 📴 **Offline First** — Play anywhere without an internet connection
- 🎯 **Progressive Difficulty** — Games adapt to the user's skill level
- 🌙 **Clean UI** — Intuitive, distraction-free interface designed for all ages
- 🔒 **Privacy Focused** — No ads, no tracking, no data collection
- ⚡ **Lightweight & Fast** — Optimized for low-end devices
- 🔄 **Auto-Updates** — Built-in CI/CD pipeline delivers updates automatically

---

## 🚀 Download

Get the latest stable release or try the continuous development build:

| Release Type | Download | Stability |
|-------------|----------|-----------|
| **Stable** | [Latest Release](https://github.com/i-sifat/OnushilonHub_Games/releases/latest) | ✅ Production Ready |
| **Continuous** | [Continuous Build](https://github.com/i-sifat/OnushilonHub_Games/releases/tag/continuous) | ⚡ Latest Commits |

### Installation

1. Download the `.apk` file from the [Releases](https://github.com/i-sifat/OnushilonHub_Games/releases) page
2. Open the downloaded file on your Android device
3. Allow installation from unknown sources if prompted
4. Launch **OnushilonHub Games** and start learning!

---

## 🛠️ Build from Source

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (stable channel)
- Android SDK / Android Studio
- JDK 17

### Clone & Run

```bash
# Clone the repository
git clone https://github.com/i-sifat/OnushilonHub_Games.git
cd OnushilonHub_Games

# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK
flutter build apk --release

# Build release AAB (Play Store)
flutter build appbundle --release
```

### Release Signing (Maintainers)

The project uses a CI/CD pipeline for automated signed releases. For local release builds, place your keystore at `android/app/upload-keystore.jks` and create `android/key.properties`:

```properties
storePassword=your_password
keyPassword=your_password
keyAlias=upload
storeFile=upload-keystore.jks
```

---


### Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter 3.x |
| **Language** | Dart |
| **Platform** | Android (API 21+) |
| **State Management** | Flutter SetState / Provider |
| **Storage** | SharedPreferences / SQLite |
| **CI/CD** | GitHub Actions |
| **Build** | Gradle (Kotlin DSL) |

---

## 🔄 CI/CD Pipeline

This repository uses **GitHub Actions** for fully automated builds and releases.

See [`.github/workflows/build-release.yml`](.github/workflows/build-release.yml) for the full configuration.

---

## 🤝 Contributing

Contributions are welcome! Whether it's bug fixes, new games, or UI improvements:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your code follows the existing style and includes appropriate tests where applicable.

---

## 📝 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---
<p align="center">
  <sub>Built with ❤️ by <a href="https://github.com/i-sifat">@i-sifat</a></sub>
</p>
