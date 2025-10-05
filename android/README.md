# HXGNY Android App

This module contains the Jetpack Compose implementation of the HXGNY mobile experience, feature-for-feature with the iOS SwiftUI app. It integrates the same Google Sheets content feeds, cached JSON storage, and saved schedule functionality so both platforms stay in sync.

## Highlights
- Compose UI screens for Home, Classes, Class Details, My Schedule, and the one-column info sections (School Intro, Weekly News, Lost & Found, Sponsors, Contact, Join Us).
- Zoomable building, parking, and calendar maps with pinch-to-zoom, panning, and double-tap reset.
- Class search with category cycle filter and on-site toggle, plus saving/removing classes locally.
- Shared caching layer that mirrors iOS behaviour: on-device JSON cache with automatic refresh from OpenSheet endpoints and saved schedule persistence via shared preferences.
- Play Store update shortcut (market://details?id=com.hxgny.app).

## Project Structure
android/
  build.gradle.kts            # Root Gradle plugins
  settings.gradle.kts         # Includes :app module
  gradle.properties           # Standard JVM/Android flags
  app/
    build.gradle.kts          # Compose + Kotlin serialization config
    proguard-rules.pro        # Placeholder
    src/main/
      AndroidManifest.xml
      assets/                 # (optional) JSON seeds
      res/                    # Drawable/logo/map assets
      java/com/hxgny/app/
        data/                 # Cache + network repository
        model/                # Shared serializable data models
        ui/                   # Compose screens and theme
        MainActivity.kt       # Entry point

## Getting Started
1. Open in Android Studio (Giraffe or newer). When prompted, let it download the Android Gradle Plugin (AGP 8.6) and Kotlin 1.9.24 if not already installed.
2. Sync the project. Android Studio will read build.gradle.kts and fetch Compose, Navigation, and Kotlin serialization dependencies.
3. Configure an emulator or device running Android 7.0 (API 24) or later.
4. Run the app. Use the app run configuration or execute ./gradlew :app:installDebug from the android directory (after adding the Gradle wrapper if your environment requires it).

Note: Network access is required for the initial refresh from the OpenSheet endpoints. Cached JSONs are stored under the app's files directory so subsequent launches work offline.

## Environment Variables
No secrets are required - Google Sheets URLs are hard-coded in SheetConfig. Update them in com.hxgny.app.data.SheetConfig if you migrate to new feeds.

## Next Steps
- Add instrumented/UI tests for navigation and data refresh flows.
- Hook up Firebase or another backend by implementing additional providers inside HxgnyRepository.
- Package the Play Store build by supplying a production applicationId and signing config.


