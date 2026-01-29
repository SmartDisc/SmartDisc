# Git Commit History - SmartDisc Project

**Saved on:** $(date)
**Current HEAD:** 7febedd (BLE improved)

## 📋 Complete Commit History

### Latest Commits (Current State)

1. **7febedd** - `BLE improved` (2026-01-25)
   - Improved BLE device detection
   - Changed device filter to "Bodenstation-ESP32"
   - Enhanced platform detection
   - Better error handling

2. **85361cb** - `BLE implemented` (2026-01-23)
   - Initial BLE implementation

3. **47d752f** - `formatted files` (2026-01-22)
   - Code formatting

4. **de18d5e** - `formatted` (2026-01-22)
   - Code formatting

5. **192d41e** - `scheibe_id corrected` (2026-01-22)
   - Fixed disc ID handling

6. **bdef6b7** - `german translated to english` (2026-01-22)
   - Translation changes

7. **5ca03e7** - `dummy daten für fallback` (2026-01-22)
   - Fallback dummy data

8. **fb049aa** - `deleted highscore pop up` (2026-01-22)
   - Removed highscore popup

9. **fc47894** - `Revert "highscorepopup"` (2026-01-22)
   - Reverted highscore popup

10. **da07910** - `highscorepopup` (2026-01-20)
    - Added highscore popup

### Earlier Commits (Backend/Frontend Development)

- **0ed6e06** - popup animation
- **4ae66d9** - Fix code issues reported by flutter analyze
- **4de82fa** - Improve analysis and history screens
- **32a0ba1** - Refactor backend and frontend
- **2c96493** - Simplify backend
- **788b673** - Cleaned Up Code
- **002b36d** - simplify backend to store only throw data
- **3c7b990** - regestrierungssystem gefixt
- **fdb6447** - komprimiert und Profil-Ladezustand
- **39393a7** - komprimiert/aufgeteilt
- **9e9bf75** - Loginsystem erweitert
- **b75e542** - analysis screen improvements
- **9568488** - analyse-seite fertig
- **f987676** - profilseite gemacht
- **af13580** - logo verbessert und rollenseite
- **344ad8d** - change between player and trainer
- **aa70c61** - verschiedene Discs in History
- **4eec215** - reload button removed
- **477ffdb** - latest throws heading improved
- **c4948fd** - schrift in stats card geändert
- **2188c56** - add button moved
- **638e8d0** - discs screen added
- **99b02b8** - history dummy added
- **0ea1a8f** - history screen person added
- **92d2f4d** - dummy daten anzeige
- **fe73c9d** - deleted unwanted zip file
- **33eaf72** - dashboared responsive
- **6fbc8cc** - add model classes, dummy API
- **59e66d3** - swapped profile and discs
- **d5e68d8** - disc added in nav
- **0ffd5bb** - improve responsive UI
- **0177513** - app color change to light blue
- **5ec3617** - auf handy anzeige angepasst
- **b06f06d** - dashboard issues fixing
- **ced50b4** - disc mit logo eingefügt
- **bbd84c2** - dashboard fixes
- **ac9280c** - 3D-Modell hinzugefügt
- **6fe5bc2** - 3d-modell
- **65f130a** - API und Cards erstellt
- **fa4912c** - logo hinzugefügt
- **eb3efea** - einfaches loginsystem und dashboard
- **d219223** - flutter added
- **438e3e2** - deleted test
- **ff4e495** - first commit
- **ddd35ec** - Initial commit

## 🔄 How to Remove Commits

### Option 1: Reset to a Specific Commit (Keeps commits in history)
```bash
git reset --hard <commit-hash>
```

### Option 2: Remove Commits from History (Permanent - use with caution!)
```bash
# Interactive rebase to remove commits
git rebase -i <commit-hash-before-commits-to-remove>

# Or reset and force push (DANGEROUS - only if you're sure!)
git reset --hard <commit-hash>
git push --force origin main
```

## ⚠️ Important Notes

- **Commits are saved in:** `COMMIT_HISTORY_BACKUP.txt` and `COMMIT_HISTORY_DETAILED.txt`
- **Current state:** You are at commit `7febedd` (BLE improved)
- **All commits are still in Git history** - they can be recovered using commit hashes
- **To see app without certain commits:** Use `git reset --hard <commit-hash>`
- **To permanently remove:** Use interactive rebase or force push (be careful!)

## 📍 Current App State

You are currently at: **BLE improved** (7febedd)
- This includes all BLE improvements
- Platform detection
- Enhanced device filtering

## 🎯 To See App Without BLE Commits

If you want to see the app before BLE was implemented:
```bash
git reset --hard 4ae66d9  # Before BLE implementation
```

## 🎯 To See App at Specific Feature Stage

- **Before highscore popup:** `git reset --hard 0ed6e06`
- **After login system:** `git reset --hard 9e9bf75`
- **Initial dashboard:** `git reset --hard eb3efea`
