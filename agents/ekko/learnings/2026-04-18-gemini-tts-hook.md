# Gemini TTS Hook — speak-response.sh rewrite

**Date:** 2026-04-18

## What changed

Rewrote `/Users/duongntd99/.claude/hooks/speak-response.sh` (Stop hook) to use Gemini TTS instead of `say -v Samantha`.

## Key details

- **Model:** `gemini-2.5-flash-preview-tts`
- **Voice:** `Aoede` (warm female)
- **API endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent?key=<KEY>`
- **Request:** `contents[0].parts[0].text` + `generationConfig.responseModalities: ["AUDIO"]` + `speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName`
- **Response audio:** base64-encoded raw PCM L16, 24000 Hz, mono, 16-bit — returned at `candidates[0].content.parts[0].inlineData.data`
- **WAV header:** 44-byte standard RIFF WAV header prepended via python3 `struct.pack` before writing to temp file
- **Playback:** `afplay <tmpfile>.wav`, temp file deleted after
- **Fallback:** `say -v Samantha -r 200` on any failure (HTTP non-200, key missing, WAV conversion error)
- **Secret:** `secrets/gemini-claude-voice` was plaintext (not age-encrypted). Key loaded via `cat` if `decrypt.sh` returns empty.
- **Backgrounding:** whole block runs in `( ) &; disown $!` — hook returns immediately

## Available Gemini TTS voices (30 total)

Zephyr, Puck, Charon, Kore, Fenrir, Leda, Orus, Aoede, Callirrhoe, Autonoe, Enceladus, Iapetus, Umbriel, Algieba, Despina, Erinome, Algenib, Rasalgethi, Laomedeia, Achernar, Alnilam, Schedar, Gacrux, Pulcherrima, Achird, Zubenelgenubi, Vindemiatrix, Sadachbia, Sadaltager, Sulafat

## Test result

Hook invoked with a real strawberry JSONL transcript. Log showed:
- `speaking 71 chars via Gemini TTS`
- `WAV written: 269326 PCM bytes -> /tmp/claude-tts-Sk7aTK.wav`
- `Gemini TTS playback done`

Audio played successfully via `afplay`.
