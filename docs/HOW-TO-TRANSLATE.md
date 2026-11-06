# Offline translator - talk with someone who speaks another language

The translator turns what one person types into the other person's language, and back.
It runs **entirely on this computer**: nothing is sent anywhere and no internet is needed.
It uses the same AI engine as the rest of `AI-Offline\` with a small multilingual model
(Qwen3 4B, about 2.5 GB).

> Added only if you ran the installer with `-Translate` / `--translate`. If you see
> `TRANSLATE-BROWSER.bat` and `translate-browser.sh` in `AI-Offline\`, you're set. To add it later, run the
> installer again into the same drive with that flag; files you already have are kept.

> **Machine translation can be wrong.** It is a way to talk when there is no interpreter,
> not a replacement for one. For medicine, doses, consent or anything safety-critical, use
> the checks in section 3, and get a human interpreter if one can be reached.

---

## 1. Start it

| Computer | What to do |
|---|---|
| Windows | Double-click `AI-Offline\TRANSLATE-BROWSER.bat` |
| macOS | Double-click `AI-Offline/translate-browser.command` |
| Linux | Open `AI-Offline/translate-browser.sh` with your desktop's **Run in Terminal** action, or run `bash translate-browser.sh` in Terminal |

On macOS, if permission to run the copied `.command` file is missing, open Terminal
in `AI-Offline` and run `chmod +x translate-browser.command`, then double-click it.
Linux file managers differ: some require marking the `.sh` executable and enabling
"run executable text files" before double-click can launch it in a terminal.

It opens the engine's bundled chat page at **http://127.0.0.1:8087** with the interpreter
instructions already set. Keep the launcher window open. It waits up to two minutes for
its own server; an occupied port or a failed model load prints an error instead of
opening another service. On Windows, press Enter in the launcher to stop it; on
macOS/Linux, press Ctrl+C. Closing the browser tab does not stop the server.

For the original terminal interface, use `TRANSLATE.bat` on Windows or
`bash translate.sh` on macOS/Linux. Its prompt and temperature are unchanged.

It needs a 64-bit computer with about **6 GB of RAM** (it uses about 4.8 GB while it runs).
The browser needs some additional memory. No graphics card is needed; the browser
launcher uses the CPU. Close other programs if it is slow.

The browser launcher needs Windows PowerShell 5.1 on Windows, or Bash, `curl` and
`open` (macOS) / `xdg-open` (Linux), plus a desktop browser. If opening the browser
fails after startup, open the printed address yourself. A missing engine, model or
configuration is reported in the launcher; re-run the installer with Translate enabled.

## 2. Use it

1. **Start a new chat and send the two languages first**, for example `English and Spanish`.
   It answers `Ready`.
2. **Take turns.** Each person types in their own language and sends the message. The answer is
   the same message in the other language. Turn the screen so the other person can read it.
3. To change languages or start over in the browser, start a **new chat**, then send
   the two languages again. The browser's Settings should show the interpreter system
   message and temperature **0.2**. Saved settings can override the launcher's defaults:
   use **Reset to Default** or a fresh private browser window if those settings differ.
   The launcher supplies defaults; it does not lock the browser's settings.
4. Long talks can fill the 4096-token conversation limit. Start a new chat and name
   the languages again; repeat any details still needed.

In the terminal interface, type the languages and press Enter, then take turns. Use
`/clear` to start over and `/exit` or Ctrl+C to quit. In llama.cpp
   b12110, `--context-shift` does not remove this chat-mode limit. If it reports
   `exceeds the available context size`, type `/clear` and name the two languages
   again. This discards the old conversation; repeat any details still needed.

```text
> English and Spanish
Ready
> Do you have any allergies to medicine?
¿Tiene alguna alergia a medicamentos?
> Sí, a la penicilina.
Yes, to penicillin.
```

## 3. Checks that catch most mistakes

- **Short, simple sentences.** One idea per sentence. No slang, idioms or jokes.
- **Translate it back.** Copy the translation and type it in as the next message: it comes
  back in your own language. If the meaning changed, say it a different way. (In testing,
  "Where is the shelter?" came out in Ukrainian as "Where is the headquarters?" - translating
  back shows that kind of mistake.)
- **Write numbers as digits** (`500 mg`, `every 6 hours`, `7 pm`) and check them in the
  answer. Point at the number, the pill bottle or a clock as well.
- **Ask yes/no questions** and watch for a nod, a head shake or a gesture.
- **Use pictures.** Point at a body part, draw a map, show the medicine.
- If an answer comes back in the **same language you typed**, it did not translate: type
  it again, or start a new chat (terminal: `/clear`) and say the two languages again.

## 4. Which languages work

The model was tested on 30 sentences per direction from NTREX-128, a public translation
test set, in both directions with English. That is a small test, so treat the groups as a
rough guide:

| How well it did | Languages tested |
|---|---|
| **Good** - usually understandable and accurate | Spanish, French, Vietnamese |
| **Fair** - often right, check carefully | Arabic, Hindi, Ukrainian |
| **Fair into English, weaker from English** | Chinese |
| **Rough into English, mostly wrong from English** | Swahili |
| **Do not rely on it** - mostly wrong | Somali, Amharic |

For Swahili, the 3B chat (`CHAT-3B-light`) did better in testing. Ask it to translate one
sentence at a time.

Other widely spoken languages (for example Portuguese, German, Italian, Russian, Japanese,
Korean, Indonesian) were not tested. Translate back to check. Less widely spoken languages
are likely to be weak.

## 5. Privacy

The server listens only on this computer's loopback address. The model runs offline;
the launcher uses `--offline` and disables the UI's online model discovery defaults.
No account or external translation service is required.

**The browser can save chats and settings on this computer**, even after you close the
tab or stop the server. Use a private browser window for sensitive conversations,
and close all private windows afterward. In a normal window, delete the chat and clear
this site's browser data when finished. The terminal interface does not save chats.

## 6. Where it comes from

- Model: [Qwen3-4B-Instruct-2507](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507)
  by the Qwen team, Apache License 2.0. The file on this drive is the Q4_K_M
  [GGUF version](https://huggingface.co/bartowski/Qwen_Qwen3-4B-Instruct-2507-GGUF).
- Engine: [llama.cpp](https://github.com/ggml-org/llama.cpp), MIT License (the same engine
  as the other AI launchers; see [HOW-TO-RUN-OFFLINE-AI](HOW-TO-RUN-OFFLINE-AI.html)).

The browser configuration uses the flat `systemMessage` and `temperature` preferences
verified in [llama.cpp b12110's UI settings keys](https://github.com/ggml-org/llama.cpp/blob/b12110/tools/ui/src/lib/constants/settings-keys.constants.ts).
The [server documentation](https://github.com/ggml-org/llama.cpp/blob/b12110/tools/server/README.md)
calls `--webui-config-file` an alias for `--ui-config-file`; both accept a JSON file.
Older engines may lack these flags, and future UI versions may change preferences.
Re-run the installer to refresh an old engine if startup reports an unknown flag.
