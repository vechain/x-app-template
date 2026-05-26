---
name: translate
description: Manages translation files for react-i18next. Adds/removes keys across 15 languages, keeps files sorted, enforces fixed-word rules, and verifies sync with en.json.
license: MIT
---

# Translate Skill

Manages translation files in `apps/frontend/src/i18n/languages/`.

## Translation Files

- 15 languages: en (source), de, es, fr, hi, it, ja, ko, nl, pt, sv, tr, tw, vi, zh
- Format: flat JSON key-value pairs (keys = English phrases)
- Interpolation: `{{variableName}}`
- Library: `react-i18next` configured in `apps/frontend/src/i18n/index.tsx`
- Language list defined in `apps/frontend/src/i18n/index.tsx` (`languages` array)

## When Adding New Translation Keys

1. Add the new key to `en.json` with the English value
2. Add the same key to ALL other language files with the correct translation for the language of the file
3. After adding to all files, sort ALL translation files alphabetically by key (case-insensitive)

## When Removing Translation Keys

1. Remove the key from ALL 15 language files
2. Files should remain sorted after removal

## Sorting Rules

- All translation JSON files MUST have keys sorted alphabetically (case-insensitive)
- Sorting applies to ALL language files, not just `en.json`
- After any modification, verify keys are sorted

## Sort Procedure

For each `.json` file in `apps/frontend/src/i18n/languages/`:

1. Parse the JSON
2. Get all keys and sort them case-insensitively
3. Rebuild the object with sorted keys
4. Write back with 2-space indentation and trailing newline

Use a Node.js script or jq to sort. Example with Node.js:

```bash
node -e "
const fs = require('fs');
const glob = require('glob');
const files = glob.sync('apps/frontend/src/i18n/languages/*.json');
files.forEach(f => {
  const obj = JSON.parse(fs.readFileSync(f, 'utf8'));
  const sorted = Object.keys(obj)
    .sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }))
    .reduce((acc, key) => { acc[key] = obj[key]; return acc; }, {});
  fs.writeFileSync(f, JSON.stringify(sorted, null, 2) + '\n');
});
"
```

## Sync Check

After any translation change, verify:

- `en.json` has all keys that exist in code (search for `t("..."`) usage)
- All non-English files have the EXACT same keys as `en.json`
- Missing keys in non-English files get the correct translation for the language of the file
- Extra keys in non-English files (not in `en.json`) should be removed
- All files are sorted alphabetically by key

## Fixed Words

See `apps/frontend/src/i18n/fixedWords.json`. Grouped by language code (`"all"` applies to every language).

Two use cases:

1. **Untranslated words** — value equals the English word (e.g. `"round": "round"` keeps "round" in English for Italian)
2. **Fixed translations** — value is the mandatory translation for that concept (e.g. `"endorsement": "supporto"` means always use "supporto" for endorsement in Italian)

When translating, ALWAYS check this file first. If a word has a fixed translation for the target language, use it consistently in every sentence.

## VeChain Kit: bi-directional language sync

If the app uses `@vechain/vechain-kit`, keep Kit UI language in sync with the host app:

- **App → Kit:** Inside `VeChainKitProvider`, subscribe to `i18n.on("languageChanged", ...)` and call `setLanguage(lng)` from `useCurrentLanguage()` so when the user changes language in the app (e.g. footer selector), Kit updates.
- **Kit → App:** Pass `language={i18n.language}` and `onLanguageChange={(lng) => i18n.changeLanguage(lng)}` into `VeChainKitProvider` so when the user changes language in Kit (e.g. wallet modal), the app updates.

See the **vechain-kit** skill reference [translations-vechain-kit.md](https://github.com/vechain/vechain-ai-skills/blob/main/skills/vechain-kit/references/translations-vechain-kit.md) for the full implementation pattern.

## Pre-commit and ESLint (missing / unused keys)

- **Unused keys in en.json:** Run a script that finds keys in `en.json` never used in code (`t("...")`, `i18nKey="..."`) and exit non-zero so pre-commit fails. Run when `en.json` or code is staged.
- **Missing keys in other locales:** Run a script that compares each locale's keys to `en.json` and fails if any locale has missing or extra keys. Run when any translation file is staged or in CI.
- **ESLint:** Optionally add `eslint-plugin-i18next` (or similar) to flag missing keys in the editor/lint.

See the **vechain-kit** skill reference [translations-vechain-kit.md](https://github.com/vechain/vechain-ai-skills/blob/main/skills/vechain-kit/references/translations-vechain-kit.md) for a short summary table.
