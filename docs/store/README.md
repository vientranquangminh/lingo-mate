# Store listing kit

Everything Play Console asks for before the closed test (T-2.9), kept next to the code so it
changes with it.

| File | What |
|---|---|
| `listing.en.md` | Master listing (D-22): name, short and full description, category |
| `listing.vi.md` | Vietnamese listing |
| `data-safety.md` | Answers for App content → Data safety |
| `screenshots/en`, `screenshots/vi` | Phone screenshots, 1080 × 2340 |
| `../../hosting/public/` | Privacy policy pages (`/privacy`, `/privacy-vi`) for Firebase Hosting |

## Privacy policy

1. Replace `CONTACT_EMAIL` in `hosting/public/privacy.html` and `privacy-vi.html` with the
   support address shown on the store listing.
2. Deploy the pages: `firebase deploy --only hosting --project <project-id>`. The app opens
   the URL in Remote Config `privacy_policy_url`, which defaults to
   `https://lingo-mate-4f38d.web.app/privacy` (the dev project). Once the production
   project exists (T-2.1), deploy there and set `privacy_policy_url` in its Remote Config.
3. Paste the same URL into Play Console → App content → Privacy policy.

Update the pages, and their effective date, before shipping anything that changes what
leaves the phone: sign-in (T-2.2), Live in production (T-2.4), purchases (T-2.6), account
deletion (T-2.12). The release checklist (doc 07) asks that Data safety and the policy
match the build.

## Screenshots

The screenshots come from a widget test that runs the real app with seeded data and the
Be Vietnam Pro font:

```bash
fvm flutter test test/store --update-goldens --dart-define=STORE_SCREENSHOTS=true
```

It writes `screenshots/<locale>/NN-name.png` (Conversation, Home, meeting summary,
phrasebook, quick phrases, review, offline packs). Without the define the suite is skipped, so CI
does not run it. Phones show CJK text with system fonts, which the test font lacks, so the
seeded content sticks to Vietnamese and English.

Play also needs a 512 × 512 icon (`assets/brand/png`, see `assets/brand/README.md`) and a
1024 × 500 feature graphic (not made yet).

## Before the first upload

- The store name waits on the trademark check (OQ-7).
- The Gemini free tier lets Google use the text for product improvement; the policy says
  so. Revisit before production.
