# CourtIQ — First Build Checklist

No external packages. No Firebase. Pure SwiftUI + mock data.
Estimated time: 5–10 minutes.

---

## What you need

- A Mac running macOS 14 (Sonoma) or later
- Xcode 15 or later — download free from the Mac App Store
- The CourtIQ source files (already in this repo)

---

## Part 1 — Get the source files onto your Mac

If you haven't already:

```bash
git clone https://github.com/canayan1/CourtIQ
```

Or download the ZIP from GitHub → Code → Download ZIP, then unzip it.

You should have a folder called `CourtIQ` on your Mac. Inside it:

```
CourtIQ/
├── CourtIQ/
│   ├── App/
│   │   ├── CourtIQApp.swift
│   │   └── MainTabView.swift
│   ├── Core/Models/
│   │   └── Quiz.swift
│   └── Features/Quiz/
│       ├── QuizView.swift
│       └── QuizViewModel.swift
├── BUILD_CHECKLIST.md
├── CLAUDE.md
└── README.md
```

---

## Part 2 — Create a new Xcode project

1. Open **Xcode**
2. On the welcome screen, click **Create New Project**
   (or go to **File → New → Project** from the menu bar)
3. Select **iOS** at the top, then choose **App** → click **Next**
4. Fill in the form:
   - **Product Name:** `CourtIQ`
   - **Team:** select your Apple ID, or leave as *None* (simulator still works)
   - **Organization Identifier:** `com.yourname` (e.g. `com.can` — anything works)
   - **Interface:** `SwiftUI`
   - **Language:** `Swift`
   - Leave **"Include Tests"** unchecked
5. Click **Next**
6. **Important — save location:**
   Navigate into your cloned `CourtIQ` folder and click **Create**
   This places `CourtIQ.xcodeproj` inside the `CourtIQ` folder.

---

## Part 3 — Remove Xcode's auto-generated files

Xcode creates placeholder files you don't need. Remove them:

1. In the left sidebar (file navigator), find **`ContentView.swift`**
   - Right-click it → **Delete** → **Move to Trash**

2. Find the **`CourtIQApp.swift`** that Xcode just created
   (it will be at the top level of the CourtIQ group, NOT inside an `App/` folder)
   - Right-click it → **Delete** → **Move to Trash**

> Why: The repo has its own `CourtIQApp.swift` with the correct setup.
> Keeping both causes a "multiple @main" build error.

---

## Part 4 — Add the source files

1. In the left sidebar, right-click the **CourtIQ** group (the folder icon, not the project)
2. Click **"Add Files to 'CourtIQ'..."**
3. In the file picker, navigate into the `CourtIQ/CourtIQ/` folder
4. Select the **`App`** folder — hold **Cmd** and also select **`Core`** and **`Features`**
   (select all three folders at once)
5. At the bottom of the file picker, make sure:
   - **"Copy items if needed"** is **unchecked** (the files are already in place)
   - **"Create groups"** is selected (not "Create folder references")
   - **"Add to targets: CourtIQ"** is **checked**
6. Click **Add**

You should now see `App`, `Core`, and `Features` groups in the sidebar with all 5 Swift files inside them.

---

## Part 5 — Set the deployment target

1. Click the **CourtIQ** project at the very top of the sidebar (the blue icon)
2. In the main editor, click the **CourtIQ** target under "Targets"
3. Click the **General** tab
4. Under **"Minimum Deployments"**, set iOS to **17.0**

> Why: `@Observable` — used in QuizViewModel — requires iOS 17.

---

## Part 6 — Build and run

1. In the toolbar at the top of Xcode, click the device selector (next to the play button)
2. Choose any **iPhone simulator** — iPhone 16 is a good choice
3. Press **Cmd + R** (or click the ▶ play button)
4. Xcode builds the app and launches it in the simulator

---

## What you should see

The app opens with **3 tabs** at the bottom:

| Tab | What it shows |
|-----|--------------|
| Quiz | A 3-question tennis scenario quiz with tap-to-answer, explanation reveal, score, and restart |
| Daily Tip | "Coming Soon" placeholder text |
| Profile | "Coming Soon" placeholder text |

The quiz works fully offline with mock data. No login, no network needed.

---

## If something goes wrong

**"Multiple commands produce..." or "@main" error**
→ You have two `CourtIQApp.swift` files. Go back to Part 3 and delete the one Xcode generated (not the one in the `App/` folder).

**"Cannot find type 'QuizView' in scope"**
→ The source files weren't added to the target. Select each Swift file in the sidebar, open the right panel (File Inspector), and make sure "Target Membership: CourtIQ" is checked.

**Build succeeds but app is blank**
→ The wrong file is set as the entry point. Make sure `CourtIQApp.swift` (inside the `App` group) is the only file with `@main`.

---

## Audit status (as of current commit)

| File | Status |
|------|--------|
| CourtIQApp.swift | Clean |
| MainTabView.swift | Clean |
| Quiz.swift | Clean |
| QuizView.swift | Clean |
| QuizViewModel.swift | Clean |

No external dependencies. No async. No network. Safe to build on first attempt.
