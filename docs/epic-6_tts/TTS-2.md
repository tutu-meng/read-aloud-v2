### TTS-2: First-time TTS Language Selection (EN/ZH-Hans)

#### Goal
Let users choose a speech language the first time they tap the TTS button. Support English and Simplified Chinese initially, persist the choice, and use it for subsequent reads.

#### Scope (minimal)
- Languages: English (United States) and Chinese (Simplified, Mainland)
- Persist selection in `UserSettings` as a BCP‑47 code
- Prompt only once on first use; thereafter use the saved language automatically
- Provide a path to change language later via Settings (out of scope to implement here but included in plan)

#### UX
- First tap on the TTS button when no language is set:
  - Present a small sheet/alert with two options:
    - English (United States)
    - Chinese (Simplified)
  - Primary action: “Start Reading” uses the selected language and saves it
  - Secondary action: “Cancel” dismisses without starting
- Subsequent taps: start/pause/resume TTS using saved language with no prompt
- Optional: Long-press TTS button to re-open picker (future enhancement)

#### Data model
- Add `speechLanguageCode: String?` to `UserSettings` (persisted)
  - Values (initial):
    - English (US): `en-US`
    - Chinese (Simplified): `zh-CN`

#### Implementation outline (minimal change)
- ReaderViewModel
  - Add `@Published var shouldPresentTTSPicker = false`
  - In `toggleSpeech()`:
    - If `coordinator.userSettings.speechLanguageCode` is nil → set `shouldPresentTTSPicker = true` and return
    - Else proceed to start/pause using `SystemSpeechService`
  - Add a ViewModel method `confirmTTSLanguageSelection(code: String)`:
    - Save to `UserSettings` via `AppCoordinator.saveUserSettings(...)`
    - Start speaking current page using the selected language
- ReaderView
  - Observe `shouldPresentTTSPicker` to present a simple action sheet with two choices
  - On selection, call `viewModel.confirmTTSLanguageSelection(code:)`
- SystemSpeechService
  - Enhance `speak(_ text: String, rate: Float)` to new overload `speak(_ text: String, rate: Float, languageCode: String)`
  - Use `AVSpeechUtterance(string:)` with `utterance.voice = AVSpeechSynthesisVoice(language: languageCode)`

#### Acceptance criteria
- First TTS tap prompts for language when none is set
- Choosing English starts TTS in English and persists `en-US`
- Choosing Chinese starts TTS in Chinese and persists `zh-CN`
- Subsequent taps do not prompt again and use the saved language
- Setting persists across app restarts
- If language is changed in Settings later, new selection is used immediately

#### Validation plan
- Unit tests (ReaderViewModel)
  - Given no `speechLanguageCode`, `toggleSpeech()` sets `shouldPresentTTSPicker = true` and does not flip to speaking
  - After calling `confirmTTSLanguageSelection("en-US")`, `toggleSpeech()` starts speaking without re-prompt
  - Persisted selection remains after re-instantiating coordinator/view model
- Unit tests (SystemSpeechService)
  - Verify that the `speak(..., languageCode:)` path sets `utterance.voice` using the given code
- Manual checks
  - English sample content reads in English voice
  - Chinese sample content reads in Simplified Chinese voice
  - Quit and relaunch app: subsequent TTS taps do not prompt and retain chosen language

#### Risks / notes
- Device language availability: `AVSpeechSynthesisVoice(language:)` may return nil on some simulators if voices are missing. Fallback to default voice if nil.
- Future: expand languages and add a dedicated Speech section in Settings with a language picker.

#### Mermaid: First-time TTS selection flow
```mermaid
flowchart TD
  A[User taps TTS] --> B{Has saved speechLanguageCode?}
  B -- Yes --> C[Speak current page with saved language]
  B -- No --> D[Present language picker\nEN (en-US) / ZH-Hans (zh-CN)]
  D -->|User selects EN| E[Save en-US to UserSettings]
  D -->|User selects ZH| F[Save zh-CN to UserSettings]
  E --> G[Speak current page with en-US]
  F --> H[Speak current page with zh-CN]
```

#### Tracking
- Ticket: TTS-2
- Out of scope here: full Settings UI for language change; long-press gesture on TTS button


