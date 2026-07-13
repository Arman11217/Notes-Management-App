# 📝 Notes Management App

A complete Flutter + Firebase Firestore Notes Management Application. Users can **Create**, **Read**, **Update**, and **Delete** notes with title and description stored in the cloud.

Built as an assignment project for the **bdapps Gladiators - NADB26** program.

---

## ✨ Features

| # | Feature | Description |
|---|---------|-------------|
| 1 | **Create Note** | Add a new note with title and description |
| 2 | **View Notes** | See all notes in a real-time updating list |
| 3 | **Update Note** | Edit any existing note's title/description |
| 4 | **Delete Note** | Remove notes with confirmation dialog |
| 5 | **Real-time sync** | Stream-based updates from Firestore |
| 6 | **Material 3 UI** | Modern, clean interface |

---

## 🛠️ Tech Stack

- **Flutter** (Dart) - UI framework
- **Firebase Core** - Firebase initialization
- **Cloud Firestore** - NoSQL cloud database
- **Material Design 3** - UI components

---

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase configuration
├── models/
│   └── note.dart                      # Note data model
├── services/
│   └── firestore_service.dart         # CRUD operations
└── screens/
    ├── notes_list_screen.dart         # List of all notes
    └── add_edit_note_screen.dart      # Add/Edit form
```

---

## 🚀 Setup Instructions

### Prerequisites

- Flutter SDK installed (>= 3.x)
- Dart SDK installed
- Android Studio / VS Code with Flutter extensions
- A Firebase account

### Step 1: Get Dependencies

```bash
flutter pub get
```

### Step 2: Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** → name it (e.g. `notes-management-app`) → Continue
3. Disable Google Analytics (optional) → Create project
4. From project overview, click the **Android icon** to add an Android app
5. **Android package name:** `com.example.notes_management_app`
6. **App nickname:** Notes Management (optional)
7. Click **Register app** → **Download google-services.json**
8. Place `google-services.json` in `android/app/` folder
9. Skip the remaining SDK steps (Flutter handles them via plugin)

### Step 3: Enable Firestore

1. In Firebase Console → **Build** → **Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** (for development)
4. Select a location → Enable

> ⚠️ Test mode lets anyone read/write for 30 days. For production, set proper security rules.

### Step 4: Generate Firebase Config

Install FlutterFire CLI (one time):
```bash
dart pub global activate flutterfire_cli
```

Then run:
```bash
flutterfire configure
```

This will:
- Detect your Firebase project
- Replace placeholders in `lib/firebase_options.dart` with real values
- Set up `firebase_options.dart` properly

### Step 5: Run the App

```bash
# Check that everything is OK
flutter doctor

# Run on connected device/emulator
flutter run
```

---

## 🧪 Test the App

```bash
flutter test
```

Includes basic unit tests for the `Note` model.

---

## 📖 CRUD Operations Explained

### Create (Add Note)
- Tap the **+ New Note** floating button
- Enter title (required) and description
- Tap **Save Note**

### Read (View Notes)
- Notes List Screen auto-loads all notes
- Real-time stream updates the list when Firestore data changes
- Newest notes appear at top (sorted by `updatedAt`)

### Update (Edit Note)
- Tap any note in the list
- Modify title/description
- Tap **Update Note**

### Delete (Remove Note)
- Tap the red trash icon on a note
- Confirm deletion in the dialog

---

## 🔥 Firestore Data Structure

Collection: `notes`

```
notes (collection)
└── {documentId} (auto-generated)
    ├── title: string
    ├── description: string
    ├── createdAt: timestamp
    └── updatedAt: timestamp
```

---

## 📤 Submission Guide

### 1. Add files to .gitignore (BEFORE first git add)

Edit `.gitignore` and make sure these lines are present:
```
# Firebase
android/app/google-services.json
lib/firebase_options.dart
```

### 2. Create GitHub Repository

```bash
git init
git add .
git commit -m "Initial commit - Notes Management App"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/notes-management-app.git
git push -u origin main
```

### 3. Make Repository Public

On GitHub → Settings → General → **Danger Zone** → Change visibility → Public

### 4. Submit Link

Copy your GitHub repo URL: `https://github.com/YOUR_USERNAME/notes-management-app`

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| `No Firebase App '[DEFAULT]'` | Run `flutterfire configure` to set up `firebase_options.dart` |
| Permission denied on Firestore | Check Firestore rules in Firebase Console |
| `google-services.json` not found | Download from Firebase Console → place in `android/app/` |
| White screen on launch | Check internet permission in AndroidManifest.xml |

---

## 👨‍💻 Author

Built as part of the **bdapps Gladiators - NADB26** Flutter assignment.

---

## 📄 License

This is an educational project - free to use and modify.
