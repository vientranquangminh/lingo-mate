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

## 4. Live Translate test (T-0.5)

Devtools → Live Translate streams the mic to Gemini Live Translate with the dev
`GEMINI_API_KEY` from `.env.dev` and plays the translation. One-way translates into
English; "Two-way" opens a Vietnamese and an English session on the same mic (OQ-4).
The screen shows each turn's transcripts and the median lag from the first input
transcript to the first translated audio (doc 07 §5 target: ≤ 3 s). The mic is muted while
the translation plays; use earphones to test without that gap.

The setup message follows doc 04 §4. If the session closes right after starting, the
field placement differs from the current Live Translate guide: note the error shown and
report it.

## 5. Run and collect

Devtools → Benchmark → Reload clips → Run benchmark. When it finishes, the screen shows the
CSV path. Pull it with:

```bash
adb pull /sdcard/Android/data/com.lingomate.app.dev/files/benchmark/ ./benchmark-results/
```

Columns: clip, lang, pipeline, utterance, segment start/end, ASR and translation latency
from VAD end (ms), transcript, target language, translation, reference transcript, error.
