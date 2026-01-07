# Custom Dictionary Feature Specification

## Overview

A custom dictionary feature that allows users to add specialized terms (company names, technical jargon, abbreviations) to improve transcription accuracy. Terms are sent to OpenAI Whisper as part of the prompt to guide recognition.

## User Story

As a user who frequently dictates technical content or uses non-standard vocabulary (company abbreviations like BLK, BPM, OTP, or tech terms like next.js, zshrc, react-native), I want to provide a list of these terms so that Whisper transcribes them correctly.

---

## Feature Requirements

### Core Functionality

| Requirement | Decision |
|-------------|----------|
| Term input format | Term only (no pronunciation hints or canonical forms) |
| Organization | Flat list (no categories) |
| Maximum terms | 50 terms (hard cap due to Whisper's ~224 token prompt limit) |
| Storage | Local SQLite via GRDB (same database as transcription history) |
| Sync | Local only (no iCloud/CloudKit sync) |

### Prompt Integration

Terms are included in the Whisper API prompt using a simple list format:

```
Common terms: BLK, BPM, OTP, next.js, react-native, zshrc
```

Only enabled terms are sent. The prompt is constructed at transcription time.

---

## User Interface

### Access Point

- **Menu bar only**: Add "Dictionary..." menu item to the TalkFlow menu bar dropdown
- No keyboard shortcut (can be added later if users request)

### Window Behavior

| Property | Behavior |
|----------|----------|
| Window type | Separate window (alongside History and Settings) |
| Position | Always opens centered with fixed default size |
| Size | Fixed default size, not remembered between sessions |

### Dictionary List View

| Feature | Implementation |
|---------|----------------|
| Sort order | Newest first (most recently added at top) |
| Search | Filter-as-you-type search box |
| Per-term toggle | Each term has an enable/disable switch |
| Inline editing | Click term text to edit in place |
| Delete | Immediate delete (no confirmation dialog) |

### Empty State

When dictionary is empty, show helpful onboarding:
- Brief explanation of the feature purpose
- Example terms users might add:
  - Company names/abbreviations (e.g., "BLK", "ACME")
  - Technical terms (e.g., "next.js", "kubectl")
  - Industry jargon (e.g., "OTP", "BPM")

### Add Term Flow

1. Single text input field at top of window
2. User types term and presses Enter (or clicks Add button)
3. Term is validated and added immediately (auto-save)
4. Input field clears, ready for next term

---

## Data Model

### Dictionary Term

```swift
struct DictionaryTerm: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var term: String           // The actual term text
    var isEnabled: Bool        // Per-term enable/disable toggle
    var createdAt: Date        // For "newest first" sorting
    var updatedAt: Date        // For tracking edits
}
```

### Database Schema

```sql
CREATE TABLE dictionary_terms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    term TEXT NOT NULL,
    is_enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX idx_dictionary_term ON dictionary_terms(term);
```

### Migration

Use GRDB's built-in migration system (consistent with existing history migrations).

---

## Validation Rules

| Rule | Behavior |
|------|----------|
| Character restrictions | None - allow anything (emojis, special chars, spaces, multi-word phrases) |
| Length restrictions | None |
| Whitespace | Trim leading/trailing whitespace only |
| Duplicates | Case-preserving deduplication ("BLK" and "blk" can coexist, but not "BLK" twice) |
| Empty terms | Reject empty or whitespace-only terms |

### Limit Enforcement

When user attempts to add term #51:
- Block the addition
- Show error message: "Dictionary limit reached (50 terms). Delete some terms to add new ones."
- Do not offer auto-replace or upgrade prompts

---

## Integration Points

### OpenAIWhisperService

Modify transcription request to include dictionary terms in the prompt:

```swift
func buildPrompt(with dictionaryTerms: [String]) -> String {
    guard !dictionaryTerms.isEmpty else { return "" }
    return "Common terms: \(dictionaryTerms.joined(separator: ", "))"
}
```

### DependencyContainer

Add `DictionaryStorage` as a new lazily-initialized service.

### MenuBarView

Add "Dictionary..." menu item that opens the Dictionary window.

---

## Behavior Specifications

### Auto-Save

All changes are saved immediately:
- Adding a term → saved instantly
- Editing a term → saved on blur/enter
- Toggling enable/disable → saved instantly
- Deleting a term → removed instantly

No "Apply" or "Save" button needed.

### Error Handling

- API errors related to prompt length: Show generic error message only (don't specifically mention dictionary)
- No automatic retry without dictionary on prompt errors

---

## Logging

Detailed logging for debugging (all logs stay local):

```swift
Logger.shared.debug("Dictionary: Loaded \(count) terms")
Logger.shared.debug("Dictionary: Applying \(enabledCount) enabled terms to prompt")
Logger.shared.debug("Dictionary: Full term list: \(terms.joined(separator: ", "))")
Logger.shared.info("Dictionary: Added term '\(term)'")
Logger.shared.info("Dictionary: Removed term '\(term)'")
Logger.shared.info("Dictionary: Toggled term '\(term)' to \(isEnabled ? "enabled" : "disabled")")
```

---

## File Structure

```
TalkFlow/
├── Features/
│   └── Dictionary/
│       ├── DictionaryStorage.swift      # GRDB persistence layer
│       ├── DictionaryManager.swift      # Business logic, validation
│       └── DictionaryTerm.swift         # Data model
├── UI/
│   └── Dictionary/
│       ├── DictionaryWindow.swift       # NSWindow wrapper
│       ├── DictionaryView.swift         # Main SwiftUI view
│       ├── DictionaryTermRow.swift      # Individual term row component
│       └── AddTermView.swift            # Term input component
└── TalkFlowTests/
    └── DictionaryTests/
        ├── DictionaryStorageTests.swift
        └── DictionaryManagerTests.swift
```

---

## Testing Requirements

### Unit Tests

- `DictionaryStorageTests`: CRUD operations, deduplication, limit enforcement
- `DictionaryManagerTests`: Validation logic, prompt building, enable/disable

### Test Cases

1. Add term successfully
2. Add duplicate term (exact match) → rejected
3. Add duplicate term (different case) → allowed
4. Add term at limit (50) → success
5. Add term beyond limit (51) → blocked with error
6. Edit term inline
7. Delete term
8. Toggle term enable/disable
9. Filter terms with search
10. Build prompt with enabled terms only
11. Build prompt with empty dictionary → empty string

---

## Implementation Notes

### Token Budget

With 50 terms and the simple list format:
- Average term length: ~6 characters
- Separator overhead: 2 chars per term (", ")
- Prefix: "Common terms: " = 14 chars
- Estimated total: 14 + (50 × 8) = ~414 chars ≈ ~100-150 tokens

This leaves room within Whisper's ~224 token soft limit, accounting for variance in term lengths.

### Performance Considerations

- Dictionary is loaded once at app launch and cached in memory
- Changes update both cache and SQLite
- Prompt is built fresh for each transcription (terms may be toggled between transcriptions)

---

## Future Considerations (Out of Scope)

These features are explicitly **not** included but could be added later:
- iCloud sync across devices
- Import/export (CSV, text file)
- Categories/grouping
- Pronunciation hints
- Test transcription button
- Keyboard shortcut to open Dictionary
- Undo for delete
- Higher term limits

---

## Acceptance Criteria

- [ ] User can open Dictionary window from menu bar
- [ ] User can add terms one at a time
- [ ] User can edit terms inline
- [ ] User can delete terms immediately (no confirmation)
- [ ] User can enable/disable individual terms
- [ ] User can search/filter terms
- [ ] 50 term limit is enforced with clear error message
- [ ] Duplicate terms (exact match) are rejected
- [ ] Terms persist across app restarts
- [ ] Enabled terms are included in Whisper API prompt
- [ ] Empty state shows helpful examples
- [ ] All operations auto-save immediately
- [ ] Unit tests pass for storage and manager
