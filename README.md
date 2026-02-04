# DramaTrack

An iOS app to sync and track your MyDramaList watchlist with smart filtering and episode notifications.

## Overview
Drama is a SwiftUI app that connects to your MyDramaList account, fetches your watchlist, and helps you keep up with upcoming episodes. It includes advanced sorting, filters, offline support, and automatic notification scheduling.

## Features
- MyDramaList watchlist sync (public profiles)
- Search, sort, and filter by status
- “Watching” prioritization
- Episode list with upcoming/airing status
- Automatic episode notifications
- Offline mode using the last known watchlist
- Image + details caching
- Notification history

## Tech Stack
- Swift 5 / SwiftUI
- URLSession
- UserNotifications
- BackgroundTasks
- Local caching (UserDefaults + disk cache)

## API Disclaimer
This app uses a **non‑official** API from:
https://github.com/tbdsux/kuryana

Availability or behavior of that API can change without notice. Use at your own discretion.

## Setup
1. Clone the repository.
2. Open `Drama.xcodeproj` in Xcode.
3. Ensure you have a public MyDramaList profile (Privacy settings on MDL).

## Run
- Select a simulator or device.
- Build and run from Xcode.

## Tests
```bash
xcodebuild test -project Drama.xcodeproj -scheme Drama -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Screenshots
<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-02-04 at 19 25 11" src="https://github.com/user-attachments/assets/439b1c4d-46e2-4c9c-b53f-8bd55595f0f6" />
<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-02-04 at 19 25 28" src="https://github.com/user-attachments/assets/5f1cf975-cd9b-4253-8dc3-b8adc89f9ead" />
<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-02-04 at 19 25 35" src="https://github.com/user-attachments/assets/4daeb9c7-1083-49e6-8546-b650846d049e" />


## Roadmap
- Per‑status notification toggles
- Custom notification windows
- Exportable history

## License
MIT License. See `LICENSE`.
