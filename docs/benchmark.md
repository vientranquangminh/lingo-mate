# Running the benchmark on a phone

The devtools screen (dev flavor built with `DEVTOOLS_ENABLED=true`) runs every clip in
`manifest.json` through every benchmark pipeline in real time and writes a CSV
(doc 07 §5, AC-12.3).

## 1. Prepare the clips

Clips are 16 kHz mono 16-bit PCM WAV files (doc 00 §5). Convert other recordings with:

```bash
ffmpeg -i input.m4a -ar 16000 -ac 1 -sample_fmt s16 C01_vi_quiet.wav
```

`manifest.json` lists them:

```json
[{ "id": "C01", "file": "C01_vi_quiet.wav", "lang": "vi", "scenario": "quiet",
   "reference_transcript": "…", "reference_translation": { "en": "…" } }]
```

## 2. Copy them to the phone

Open the devtools screen once so the folder exists, then:

```bash
adb push manifest.json *.wav /sdcard/Android/data/com.lingomate.app.dev/files/benchmark/
```

## 3. Run and collect

Devtools → Benchmark → Reload clips → Run benchmark. When it finishes, the screen shows the
CSV path. Pull it with:

```bash
adb pull /sdcard/Android/data/com.lingomate.app.dev/files/benchmark/ ./benchmark-results/
```

Columns: clip, lang, pipeline, utterance, segment start/end, ASR and translation latency
from VAD end (ms), transcript, target language, translation, reference transcript, error.
