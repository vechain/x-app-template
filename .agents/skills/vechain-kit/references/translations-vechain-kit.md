# Translations and VeChain Kit

When the host app uses react-i18next and VeChain Kit, keep both in sync so that changing language in the app updates Kit UI and changing language in Kit (e.g. wallet modal) updates the app.

## Bi-directional language sync

### Host app → VeChain Kit

When the user changes language in the **host app** (e.g. footer selector calling `i18n.changeLanguage(...)`), notify Kit:

- Inside the `VeChainKitProvider` tree, subscribe to `i18n.on("languageChanged", ...)` and call Kit's `setLanguage(lng)` from `useCurrentLanguage()`.
- Do this in a small child component that has access to both `useTranslation()` and `useCurrentLanguage()`.

### VeChain Kit → host app

When the user changes language **inside Kit** (e.g. wallet modal), update the host app:

- Pass into `VeChainKitProvider`: `language={i18n.language}` and `onLanguageChange={(language) => { if (i18n.language !== language) i18n.changeLanguage(language) }}`.

### Implementation pattern

```tsx
// 1) Child: sync app i18n → Kit
function LanguageSync({ children }: { children: React.ReactNode }) {
  const { i18n } = useTranslation()
  const { setLanguage: setKitLanguage } = useCurrentLanguage()

  useEffect(() => {
    const handle = (lng: string) => setKitLanguage(lng)
    i18n.on("languageChanged", handle)
    return () => i18n.off("languageChanged", handle)
  }, [i18n, setKitLanguage])
  return <>{children}</>
}

// 2) Provider: pass current language and Kit → app handler
export function VechainKitProviderWrapper({ children }) {
  const { i18n } = useTranslation()
  const handleLanguageChange = (language: string) => {
    if (i18n.language !== language) i18n.changeLanguage(language)
  }

  return (
    <VeChainKitProvider
      language={i18n.language}
      onLanguageChange={handleLanguageChange}
      {/* ...other props */}
    >
      <LanguageSync>{children}</LanguageSync>
    </VeChainKitProvider>
  )
}
```

Host app language selector: call `i18n.changeLanguage(value)`; sync to Kit happens via `languageChanged`.

### Persist language across refreshes

In your `i18n.ts`, check localStorage first to avoid losing the selected language on page reload:

```typescript
const customLanguageDetector = {
  name: 'customDetector',
  lookup: () => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem('i18nextLng');
      if (stored && supportedLanguages.includes(stored)) return stored;
    }
    const browserLang = navigator.language.split('-')[0];
    if (supportedLanguages.includes(browserLang)) return browserLang;
    return 'en';
  },
  cacheUserLanguage: (lng: string) => {
    localStorage.setItem('i18nextLng', lng);
  },
};
```

### Optional: dayjs locale

If you use dayjs: `i18n.on("languageChanged", (lng) => { dayjs.locale(lng === "tw" ? "zh-tw" : lng) })`.

## Pre-commit and ESLint (missing / unused translations)

### Pre-commit

- **lint-staged:** Often runs ESLint + Prettier on staged `.ts/.tsx` and Prettier on `.json`. No i18n-specific step by default.
- **Unused keys in en.json:** A script can find keys in `en.json` that are never used in code (`t("...")`, `i18nKey="..."`). Run it in pre-commit when translation files or code change (e.g. when `en.json` or any `src/i18n/languages/*.json` is staged). Exit non-zero if unused keys exist so the commit fails.
- **Missing keys in other locales:** Add a script that compares each locale's keys to `en.json` and exits with an error if any key is missing or extra. Run from pre-commit (when i18n files staged) or CI.

### ESLint

- Many projects do **not** use `eslint-plugin-i18next` (or similar). To highlight missing translations: (1) enable an unused-keys script in pre-commit and a "missing keys per locale" script, or (2) add an i18n ESLint plugin and point it at the translation files.

### Summary

| Check | How to enable |
|-------|----------------|
| Unused keys in en.json | Script that scans code for `t("key")` / `i18nKey` and compares to en.json; run in pre-commit or CI |
| Missing/extra keys in other locales | Script that compares each locale JSON to en.json; run in pre-commit or CI |
| ESLint missing keys | Optional: add eslint-plugin-i18next (or similar) and configure |
