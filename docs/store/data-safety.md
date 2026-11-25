# Play Data safety answers

Answers for Play Console → App content → Data safety, for the build without accounts or
purchases (Phase 2 up to T-2.9). They follow what the code does today; the privacy policy
(`hosting/public/privacy.html`) says the same. Review them again when sign-in (T-2.2),
Live in production (T-2.4), purchases (T-2.6) or account deletion (T-2.12) ship.

Play counts data as *collected* when it leaves the device, even when a service provider
such as Google processes it for us. Data that only stays on the phone is not declared.

## Overview questions

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | Yes |
| Is all of the user data collected by your app encrypted in transit? | Yes (TLS to Firebase, Gemini, ML Kit and the model download host) |
| Do you provide a way for users to request that their data is deleted? | Yes: in-app *Me → Privacy & data → Delete all data* removes everything stored by the app. There is no account, so no web deletion link is needed yet (it becomes required with T-2.12) |
| Independent security review | No |

## Data types

| Data type (Play category) | Collected | Shared | Processed ephemerally | Required or optional | Purposes | Why |
|---|---|---|---|---|---|---|
| App activity → Other user-generated content | Yes | No | Yes | Optional (only with the Standard engine or when the user taps Summarize, How would a native say it? or Suggest reply; Offline works without it) | App functionality | Recognised text, short context and glossary terms go to Gemini through Firebase AI Logic to translate, summarise or suggest; nothing is kept on our side |
| App activity → App interactions | Yes | No | No | Optional (switch in Privacy & data) | Analytics | Firebase Analytics events `session_start`, `session_end`, `engine_switch`, `phrase_saved` with mode, engine, language pair and duration, never text |
| App info and performance → Crash logs | Yes | No | No | Optional (switch in Privacy & data) | App functionality (crash fixing) | Firebase Crashlytics; custom keys are engine, mode and pair, never transcript text |
| App info and performance → Diagnostics | Yes | No | No | Optional (same switch) | App functionality, Analytics | Device model, OS version, app version sent with analytics and crash reports |
| Device or other IDs | Yes | No | No | Optional (with analytics and crash reports) | Analytics, App functionality | Firebase installation ID / app instance ID; App Check attestation also uses a device token |

Not collected: name, email, phone number, location, contacts, photos or videos, files,
calendar, health, financial info, web browsing, messages, and **audio**. Microphone audio is
processed only in memory on the phone and never leaves it in this build. When Live ships in
production (T-2.4) add *Audio → Voice or sound recordings* (collected, processed
ephemerally, optional, App functionality).

## Notes for the form

- "Shared" is No everywhere: Google acts as a service provider processing data on our
  behalf (Firebase, Gemini API), which Play does not count as sharing.
- The free Gemini tier lets Google use the text to improve its products. The privacy
  policy says so; check again before production whether the project should move to a paid
  tier, which changes that clause.
- Play also asks for the privacy policy URL: the hosted `/privacy` page (see `README.md`).
