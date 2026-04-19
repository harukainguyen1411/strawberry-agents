# Gemini TTS Stop Hook — Research + Script

Date: 2026-04-19

## API Facts Confirmed

- Current TTS models: `gemini-2.5-flash-preview-tts`, `gemini-2.5-pro-preview-tts`, `gemini-3.1-flash-tts-preview`
- Endpoint: `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key=KEY`
- Response modality: `["AUDIO"]` in `generationConfig.responseModalities`
- Output: base64-encoded raw PCM (24kHz, mono, 16-bit) — must manually prepend WAV header for afplay
- Style injection: inline `[bracket tags]` prepended to the text content field
- 30 prebuilt voices; no per-voice rate limit docs found

## Voice Choice: Kore

Kore is described as "Firm" — the closest match to authoritative, low-register female for Evelynn's predatory tone.
Algenib (Gravelly) is a backup if Kore reads too bright in practice.

## Key Locations

- Script: `~/.claude/scripts/generate-evelynn-voice.py`
- Output dir: `~/.claude/sounds/evelynn/`
- Key lookup order: `$GEMINI_API_KEY` env → `~/.claude/secrets/gemini-api-key.txt` → strawberry `secrets/gemini-api-key.txt`

## Blocker

No Gemini API key found. Script cannot run until Duong provides it.
