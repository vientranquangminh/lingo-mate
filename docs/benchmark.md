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

## 3. Copy the speech models (T-0.4 spike)

The devtools screen builds one benchmark pipeline per model it finds in the app's
`models/` folder, and uses Silero VAD instead of the energy threshold when
`silero_vad.onnx` is there. Download the candidates on your computer, then push them:

| Candidate | Files in `models/` | Download |
|---|---|---|
| whisper.cpp | `ggml-base.bin`, `ggml-small-q5_1.bin`, … (name: `ggml-<model>.bin`) | https://huggingface.co/ggerganov/whisper.cpp/tree/main |
| sherpa-onnx Whisper | folder `sherpa-onnx-whisper-<model>/` with `<model>-encoder.int8.onnx`, `<model>-decoder.int8.onnx`, `<model>-tokens.txt` | https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models (`sherpa-onnx-whisper-base.tar.bz2`, `…-small…`) |
| Silero VAD | `silero_vad.onnx` | https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models |

Start with multilingual `base` and `small` (quantized) for both libraries (doc 04 §6).

```bash
adb push ggml-base.bin ggml-small-q5_1.bin silero_vad.onnx sherpa-onnx-whisper-base /sdcard/Android/data/com.lingomate.app.dev/files/models/
```

Devtools → Benchmark → Reload clips lists the models found and the VAD in use. The mic
test also uses Silero when it is present.

## 4. Translators (T-0.6, T-0.7)

Each speech model runs three times: ASR alone, ASR → Gemini Flash-Lite (Standard) and
ASR → ML Kit (Offline). English clips are translated to Vietnamese, every other clip to
English.

- Standard needs the dev Firebase project's AI Logic enabled with App Check (doc 04 §2–3)
  and a registered App Check debug token in `.env.dev`.
- Offline needs the ML Kit models: Devtools → Benchmark → Download offline models (vi, en).
  Further languages download the same way once the language packs screen exists (T-1.3).

## 5. Run and collect

Devtools → Benchmark → Reload clips → Run benchmark. When it finishes, the screen shows the
CSV path. Pull it with:

```bash
adb pull /sdcard/Android/data/com.lingomate.app.dev/files/benchmark/ ./benchmark-results/
```

Columns: clip, lang, pipeline, utterance, segment start/end, ASR and translation latency
from VAD end (ms), transcript, target language, translation, reference transcript,
reference translation, error. Standard/Offline latency is `translation_ms` (doc 07 §5:
p50 ≤ 2.5 s Standard, ≤ 3 s Offline).
