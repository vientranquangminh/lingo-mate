# Hosting the speech models (Firebase Storage + Remote Config)

Conversation, Listen and Meeting recognise speech on the phone with Whisper (doc 03). The
model files are too large for the APK, so the Offline packs screen (S-16) downloads them
from the URLs in the Remote Config parameter `asr_models`. While that parameter is `{}`,
the packs screen shows "Speech model not set up yet" and the voice modes say there is no
speech model.

## What the app can download

- One whisper.cpp file named `ggml-<model>.bin`, for example `ggml-base.bin` or
  `ggml-small-q5_1.bin` (https://huggingface.co/ggerganov/whisper.cpp/tree/main).
  The models are multilingual, so every language points at the same file and the phone
  keeps one copy (AC-06.6).
- sherpa-onnx models are folders of three files, so they cannot be set through `asr_models`.
  Push them with adb if needed (`docs/benchmark.md` §3). Silero VAD ships inside the app
  (`assets/models/silero_vad.onnx`) and is copied into `models/` on first use.
- For lower latency and a smaller download, prefer a quantized model such as
  `ggml-base-q5_1.bin` (~57 MB) over `ggml-base.bin` (148 MB).
- Which model to ship is open question OQ-3. Start with `ggml-base.bin` (fast), and switch
  to `ggml-small-q5_1.bin` later if Vietnamese accuracy is too low: change the file in
  Storage and the value in Remote Config, nothing else.

## Current setup (GitHub Releases, free)

The models are assets of release `models-v1` in the public repository
`vientranquangminh/lingomate-models`, and Remote Config `asr_models` points every language at
`https://github.com/vientranquangminh/lingomate-models/releases/download/models-v1/ggml-base.bin`
(147 951 465 bytes, SHA-256 `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe`).

- The repository must stay public: private release assets need a login and the phone gets 404.
- Never replace an asset of a published release; the phones check the SHA-256. Publish a new
  tag (`models-v2`) and update `asr_models` instead.
- To switch model, run step 4 below with `--url` set to the release asset URL and the same
  file, then publish the new value in Remote Config.

Firebase Storage (below) is the alternative when the Blaze plan is on.

## 1. Create the Storage bucket (once)

1. Firebase console → project `lingo-mate-4f38d` → Build → Storage → Get started.
   New Storage buckets need the Blaze (pay as you go) plan; Firebase asks to upgrade at
   this step. Set a budget alert in Google Cloud Billing if you do.
2. Pick a location close to the users (for example `asia-southeast1`) and start in
   production mode.
3. Copy the bucket name shown at the top of the Files tab, for example
   `lingo-mate-4f38d.firebasestorage.app`.

## 2. Publish the rules (once)

`storage.rules` lets anyone download a file under `models/` by its exact name, and nobody list the folder or write anything. Uploads from the console bypass the rules. The model is open source, the app checks its SHA-256 after downloading, and every download counts towards Storage egress, so keep a budget alert on the billing account.
Either paste it into Storage → Rules → Publish, or deploy it from the repository root:

```bash
firebase deploy --only storage --project lingo-mate-4f38d
```

## 3. Upload the model

Storage → Files → Create folder `models` → open it → Upload file → `ggml-base.bin`.
Keep the file name exactly as downloaded.

Check the download works without signing in (replace the bucket):

```bash
curl -sI "https://firebasestorage.googleapis.com/v0/b/<bucket>/o/models%2Fggml-base.bin?alt=media" | head -1
```

It should print `HTTP/2 200`.

## 4. Generate the `asr_models` value

From the repository root, with the same file you uploaded:

```bash
fvm dart run scripts/asr_models_config.dart --bucket <bucket> path/to/ggml-base.bin
```

It prints one entry per language of `assets/capability_matrix.json` with the file name,
download URL, size and SHA-256. The phone checks the SHA-256 after downloading, so always
run the script on the exact file in Storage. To host the file elsewhere, pass
`--url <direct download url>` instead of `--bucket`.

## 5. Set Remote Config

Firebase console → Remote Config → Add parameter (or edit `asr_models`):

- Parameter name: `asr_models`
- Data type: JSON
- Default value: the script's output
- Save → Publish changes

## 6. Check on the phone

1. Open the dev app, wait a few seconds for the background fetch, close it from recents and
   open it again (new values apply on the next start).
2. Me → Offline packs: each language now shows the speech model size. Download a pack
   (Wi-Fi only unless you allow mobile data).
3. Open Conversation, Listen or Meeting and speak.
