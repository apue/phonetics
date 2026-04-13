# ARCHITECTURE.md — Phonetics Maestro

## 1. System Architecture

```
┌──────────────────────────────────────────────────────────┐
│                        SwiftUI Views                      │
│  ┌────────────┐  ┌──────────────┐  ┌─────────┐  ┌──────┐│
│  │ WelcomeView│  │TrainingCard  │  │ History │  │Settin││
│  │            │  │View          │  │ View    │  │gsView││
│  └─────┬──────┘  └──────┬───────┘  └────┬────┘  └──┬───┘│
│        │                │               │           │     │
│  ┌─────▼──────┐  ┌──────▼───────┐  ┌────▼───────────▼───┐│
│  │            │  │TrainingCard  │  │  HistoryViewModel  ││
│  │            │  │ViewModel     │  │  SettingsViewModel ││
│  │            │  └──────┬───────┘  └────────┬───────────┘│
│  │            │         │                   │             │
├──┼────────────┼─────────┼───────────────────┼─────────────┤
│  │   Service Layer (Actors)                 │             │
│  │  ┌──────────────────┐  ┌─────────────────┐            │
│  │  │  AudioService    │  │  DataService     │            │
│  │  │  (singleton)     │  │  (singleton)     │            │
│  │  │                  │  │                  │            │
│  │  │  - TTS playback  │  │  - SQLite CRUD   │            │
│  │  │  - Mic recording │  │  - Seed import   │            │
│  │  │  - ABAB loop     │  │  - Stats update  │            │
│  │  │  - State machine │  │  - Query pairs   │            │
│  │  └──────────────────┘  └─────────────────┘            │
├───────────────────────────────────────────────────────────┤
│  Platform Layer                                           │
│  AVAudioEngine  AVSpeechSynthesizer  SQLite  FileManager │
└───────────────────────────────────────────────────────────┘
```

## 2. AudioService State Machine

```
                  ┌─────────┐
                  │  idle   │◄──────────────────────┐
                  └────┬────┘                       │
                       │                            │
            ┌──────────┼──────────┐                 │
            │          │          │                 │
            ▼          ▼          ▼                 │
     ┌──────────┐ ┌────────┐ ┌───────────┐        │
     │recording │ │playing │ │playingABAB│        │
     │          │ │(source)│ │           │        │
     └─────┬────┘ └───┬────┘ └─────┬─────┘        │
           │          │            │               │
           └──────────┴────────────┘               │
                      │                            │
                      └── stop() ──────────────────┘

playing(source) where source = .standard | .userRecording | .randomTest
```

### State Transitions

| From | To | Trigger | Guard |
|------|----|---------|-------|
| idle | recording | `startRecording()` | Mic permission granted |
| recording | idle | `stopRecording()` | — |
| idle | playing(.standard) | `playStandard(for:)` | — |
| idle | playing(.userRecording) | `playUserRecording()` | Recording exists |
| idle | playing(.randomTest) | `playRandomTest()` | — |
| idle | playingABAB | `startABABLoop()` | Recording exists |
| playing(*) | idle | Playback finished / `stop()` | — |
| playingABAB | idle | `stop()` | — |
| recording | playing(*) | ❌ ILLEGAL | — |
| playing(*) | recording | ❌ ILLEGAL | — |

## 3. Data Flow

### 3.1 App Startup Sequence

```
AppDelegate.init
  └─► DataService.shared.initialize()
        ├─► Create DB file if not exists
        ├─► Run schema migrations
        └─► Check if seed data loaded
              └─► NO: SeedDataImporter.import(from: Bundle)
                        ├─► Read seed-phonemes.json
                        ├─► Read seed-sentences.json
                        └─► INSERT into phonemes, words, pairs, sentences
```

### 3.2 Training Session Flow

```
User taps "Begin"
  └─► TrainingCardViewModel.loadNextPair()
        └─► DataService.fetchPairs(contrast: "ʌ-æ")
              └─► Returns [PhonePair] array

User taps "Random Test"
  └─► TrainingCardViewModel.playRandomTest()
        ├─► Pick A or B (50/50)
        ├─► AudioService.play(text:, voice:)  // TTS
        └─► Await user choice → update stats

User taps "Record"
  └─► AudioService.startRecording()
        └─► Save to ~/Library/.../recordings/{sessionDate}/{pairId}.caf

User taps "A/B" (ABAB Loop)
  └─► AudioService.startABABLoop(standard: "but", recording: filePath)
        └─► Loop: TTS("but") → 300ms → play(filePath) → 300ms → repeat
```

## 4. Seed Data JSON Schema

Files in `Resources/SeedData/`:

### seed-phonemes.json

```json
{
  "$schema": "seed-phonemes",
  "version": "1.0",
  "phoneme_pairs": [
    {
      "contrast": "ʌ-æ",
      "phoneme_a": {
        "symbol": "ʌ",
        "example": "cup",
        "description": "Open-mid back unrounded vowel"
      },
      "phoneme_b": {
        "symbol": "æ",
        "example": "cat",
        "description": "Near-open front unrounded vowel"
      },
      "word_pairs": [
        {
          "word_a": { "text": "but", "ipa": "/bʌt/" },
          "word_b": { "text": "bat", "ipa": "/bæt/" },
          "difficulty": 1
        }
      ]
    }
  ]
}
```

### seed-sentences.json

```json
{
  "$schema": "seed-sentences",
  "version": "1.0",
  "sentences": [
    {
      "text": "Pick it up.",
      "ipa": "/pɪk‿ɪt‿ʌp/",
      "phenomenon": "linking",
      "notes": "Consonant-vowel linking at k‿ɪ and t‿ʌ junctions"
    }
  ]
}
```

## 5. Key Dependencies (SPM)

| Package | Purpose | Version |
|---------|---------|---------|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | SQLite wrapper with Swift concurrency support | ~> 7.0 |

> Minimal dependency strategy: only GRDB for SQLite. Everything else uses Apple frameworks.

## 6. File Storage Layout

```
~/Library/Application Support/PhoneticsMaestro/
├── maestro.sqlite              # Main database
└── recordings/
    └── 2026-04-13/             # Session date directory
        ├── pair-1-attempt-1.caf
        ├── pair-1-attempt-2.caf
        └── pair-3-attempt-1.caf
```

## 7. Extension Points (V2 Preparation)

```swift
// Protocol for future data import sources
protocol DataImportService {
    func importData(into db: DataService) async throws
}

// V1: Only implementation
struct SeedDataImporter: DataImportService { ... }

// V2: CLI-generated data
// struct CLIDataImporter: DataImportService { ... }
```
