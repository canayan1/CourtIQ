# BUILD_CHECKLIST.md

Steps to open and build CourtIQ on a Mac for the first time.
No external dependencies. No Firebase. No packages. Pure SwiftUI.

---

## Requirements

| Tool    | Minimum version |
|---------|----------------|
| macOS   | 14 Sonoma      |
| Xcode   | 15             |
| iOS sim | 17             |

---

## Step 1 — Get the code

```bash
git clone https://github.com/canayan1/CourtIQ
cd CourtIQ
```

---

## Step 2 — Create the Xcode project

1. Open **Xcode**
2. **File → New → Project**
3. Choose **iOS → App** → click Next
4. Fill in:
   - Product Name: `CourtIQ`
   - Team: your Apple ID (or None for simulator-only)
   - Organization ID: `com.yourname` (anything works for now)
   - Bundle Identifier: `com.yourname.CourtIQ`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck **Include Tests**
5. **Save location: inside the cloned `CourtIQ/` folder**
   - This creates `CourtIQ/CourtIQ.xcodeproj`

---

## Step 3 — Delete Xcode's generated placeholder

In Xcode's file navigator (left sidebar), delete `ContentView.swift`:
- Right-click → Delete → Move to Trash

---

## Step 4 — Add the source files

Right-click the **CourtIQ** group in the navigator → **Add Files to "CourtIQ"**

Add these files (check "Copy items if needed" is OFF — they're already in place):

```
CourtIQ/App/CourtIQApp.swift
CourtIQ/App/MainTabView.swift
CourtIQ/Core/Models/Quiz.swift
CourtIQ/Features/Quiz/QuizView.swift
CourtIQ/Features/Quiz/QuizViewModel.swift
```

Tip: you can select all 5 at once by holding Cmd while clicking.

---

## Step 5 — Fix the entry point (if needed)

If Xcode warns about multiple `@main` or can't find the entry point:

1. Select the original generated `CourtIQApp.swift` Xcode created and delete it
2. Make sure only `CourtIQ/App/CourtIQApp.swift` is in the project

---

## Step 6 — Set deployment target

1. Click the **CourtIQ** project in the navigator (top of file list)
2. Select the **CourtIQ** target → **General** tab
3. Set **Minimum Deployments** to **iOS 17.0**

This is required because `@Observable` (used in `QuizViewModel`) was introduced in iOS 17.

---

## Step 7 — Build and run

1. Select any **iPhone simulator** (iPhone 16 recommended) in the toolbar
2. Press **Cmd + R** or click the Run button
3. The app launches with a 3-tab interface:
   - **Quiz** — a fully playable 3-question tennis scenario quiz
   - **Daily Tip** — placeholder screen
   - **Profile** — placeholder screen

---

## What works out of the box

- Tab navigation
- Quiz question flow with answer reveal
- Explanation shown after each answer
- Score summary and restart on completion

## What is intentionally not included

- Firebase / backend
- Authentication
- SwiftData / persistence
- Progress tracking
- Premium / paywall
- Tests

---

## Folder structure reference

```
CourtIQ/
├── CourtIQ.xcodeproj          ← created by you in Step 2
├── CourtIQ/
│   ├── App/
│   │   ├── CourtIQApp.swift   ← @main entry point
│   │   └── MainTabView.swift  ← 3-tab shell
│   ├── Core/
│   │   └── Models/
│   │       └── Quiz.swift     ← plain structs + mock data
│   └── Features/
│       └── Quiz/
│           ├── QuizView.swift
│           └── QuizViewModel.swift
├── BUILD_CHECKLIST.md         ← this file
├── CLAUDE.md
└── README.md
```
