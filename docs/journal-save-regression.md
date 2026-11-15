# Journal & Save Regression Checklist

Manual and automated regression cases for `GameState` (`scripts/autoload/game_state.gd`), `Journal` (`scripts/journal.gd`), and `project.godot` (`[autoload]`) on `user://save.json` (single-slot, Steam Cloud–aligned per `docs/GDD.md`).

## 1. Normal Save / Continue (`version: 2`)

- **Setup:** Start a New Game, trigger choices setting story flags (e.g., `skeptic: true`, `trusted_edith: false`, `radioed_tom: true`), and call `Journal.discover("edith_log_01")` and `Journal.discover("tom_radio_01")`.
- **Action:** Pause → **Save**, quit to desktop or Main Menu, then click **Continue**.
- **Expected:**
  - `user://save.json` contains `"version": 2`, `"scene"`, `"flags"`, and `"journal": { "entries": ["edith_log_01", "tom_radio_01"] }`.
  - Atomic write leaves no stray `user://save.json.tmp`; previous save is rotated to `user://save.json.bak`.
  - `GameState.load_game()` returns `true`, restores `current_scene` and all `flags`, and `Journal.entries()` returns `["edith_log_01", "tom_radio_01"]` in discovery order.

## 2. Existing `v1` Save Without `journal` Field

- **Setup:** Place a legacy `v1` `user://save.json` on disk:
  ```json
  {
  	"version": 1,
  	"scene": "res://scenes/game.tscn",
  	"flags": {
  		"believer": true,
  		"trusted_edith": false,
  		"radioed_tom": true
  	}
  }
  ```
- **Action:** Launch the game and click **Continue**.
- **Expected:**
  - `GameState.load_game()` returns `true` without errors.
  - All `v1` `flags` (`believer: true`, `trusted_edith: false`, `radioed_tom: true`) are preserved unchanged.
  - `Journal.entries()` initializes cleanly to `[]` (empty).
  - Subsequent **Save** upgrades the file to `"version": 2` with the `"journal"` block included.

## 3. New Game Reset (No State Bleed)

- **Setup:** Play or **Continue** a session where `GameState.flags` and `Journal._entries` are non-empty.
- **Action:** Return to Main Menu and click **New Game** (`GameState.new_game()`).
- **Expected:**
  - `GameState.flags` is `{}`.
  - `Journal.entries()` is `[]` and `Journal.cleared` is emitted.
  - `GameState.current_scene` resets to `"res://scenes/game.tscn"`.
  - Prior-session journal entries do not appear in the new run.

## 4. Duplicate Discovery (Idempotency)

- **Setup:** Active session with an empty `Journal`.
- **Action:**
  1. Call `Journal.discover("edith_log_01")` twice, then `Journal.discover("  edith_log_01  ")`, and `Journal.discover("")`.
  2. Also test `Journal.from_save_data({ "entries": ["edith_log_01", "edith_log_01", "tom_radio_01"] })`.
- **Expected:**
  - `Journal.entries()` contains `["edith_log_01"]` after step 1 (single copy, empty/whitespace IDs ignored, `entry_added` emitted only once).
  - `Journal.entries()` contains `["edith_log_01", "tom_radio_01"]` after step 2 (deduplicated, discovery order preserved).

## 5. Malformed Journal Data & Corrupt Primary Save Fallback

- **Setup (Malformed `journal` block):** Test `user://save.json` (`version: 2`) with valid `"scene"` and `"flags"`, but invalid `"journal"` values:
  - `"journal": null`
  - `"journal": "corrupt"`
  - `"journal": { "entries": "not_an_array" }`
  - `"journal": { "entries": [null, "", "   "] }`
- **Expected:** `GameState.load_game()` returns `true`, preserves the valid `scene` and `flags`, and treats `Journal.entries()` as `[]` without crashing.
- **Setup (Truncated `save.json`):** Truncate `user://save.json` mid-JSON while a valid `user://save.json.bak` exists.
- **Expected:** `GameState.has_save()` remains `true`, and `GameState.load_game()` falls back to `user://save.json.bak` cleanly.
