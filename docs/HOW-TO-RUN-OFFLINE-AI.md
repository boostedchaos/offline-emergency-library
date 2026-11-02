# Offline AI — How to Run It

This drive has an **AI chat that works with no internet**. It runs on the computer in
front of you and opens in your web browser. Nothing is installed.

## Start it

1. In the top folder of the drive, open **AI-CHAT**:
   - **Windows:** `AI-CHAT.bat`
   - **Mac:** `AI-CHAT.command` (if blocked: **System Settings → Privacy & Security → Open Anyway**)
   - **Linux:** run `bash AI-CHAT.sh` in a terminal
2. Type a number and press Enter:

| Number | Model | Needs | Use it for |
|---|---|---|---|
| **1** | Small — Qwen 3.5 4B | about 8 GB of memory | Fast answers on almost any laptop |
| **2** | Medium — Gemma 4 12B | about 16 GB of memory | Better, more careful answers |
| 3 / 4 | Same, on the graphics card | a graphics card (Windows/Linux) | Much faster if the computer has a GPU |

1. Wait up to a minute while the model loads from the drive. Your browser then opens at
   **<http://localhost:8098>**.
2. Type your question. To stop the AI, close the black AI-CHAT window.

On a Mac the graphics chip is used automatically. If option 3 or 4 fails, use 1 or 2.

## Ask about your own documents

Click **+** next to the message box and attach a **PDF** or text file. The AI reads it and
answers from it. See `HOW-TO-ASK-YOUR-DOCS`.

## Two models = a second opinion

The two models come from different makers (Alibaba's Qwen and Google's Gemma). For an
important question, ask both and compare. The small model answers at once (its
"thinking" is turned off, so it is fast). The medium model "thinks" before it answers;
click **Reasoning** to see its thinking.

## Good to know

- **It can be wrong.** Check anything safety-critical (medical, electrical, structural)
  against the reference library (OPEN-LIBRARY) and the books on this drive.
- The AI knows only what it learned when it was made, plus what you attach. It cannot
  look things up.
- Both models are Apache-2.0 licensed. The AI program is
  [llama.cpp](https://github.com/ggml-org/llama.cpp) (MIT).

## Files

| Path | What it is |
|---|---|
| `AI-Offline/models/` | The model files (`.gguf`) |
| `AI-Offline/engine/<system>/` | The AI program for Windows, macOS and Linux (`BUILD.txt` = its version) |
| `AI-CHAT.*` | The launchers |
