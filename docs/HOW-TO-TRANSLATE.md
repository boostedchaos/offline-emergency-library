# Offline translator - talk with someone who speaks another language

The translator turns what one person types into the other person's language, and back.
It runs **entirely on this computer**: nothing is sent anywhere and no internet is needed.
It uses the same AI engine as the rest of `AI-Offline\` with a small multilingual model
(Qwen3 4B, about 2.5 GB).

> Added only if you ran the installer with `-Translate` / `--translate`. If you see
> `TRANSLATE.bat` and `translate.sh` in `AI-Offline\`, you're set. To add it later, run the
> installer again into the same drive with that flag; files you already have are kept.

> **Machine translation can be wrong.** It is a way to talk when there is no interpreter,
> not a replacement for one. For medicine, doses, consent or anything safety-critical, use
> the checks in section 3, and get a human interpreter if one can be reached.

---

## 1. Start it

| Computer | What to do |
|---|---|
| Windows | Double-click `AI-Offline\TRANSLATE.bat` |
| macOS / Linux | Open Terminal in `AI-Offline` and run `bash translate.sh` |

It needs a 64-bit computer with about **6 GB of RAM** (it uses about 4.8 GB while it runs).
No graphics card is needed. Close other programs, especially web browsers, if it is slow.

## 2. Use it

1. **Type the two languages first**, for example `English and Spanish`, and press Enter.
   It answers `Ready`.
2. **Take turns.** Each person types in their own language and presses Enter. The answer is
   the same message in the other language. Turn the screen so the other person can read it.
3. To switch to other languages, type `/clear` and press Enter, then type the two new
   languages. To quit, type `/exit` or press Ctrl+C.
4. If it stops answering after a long talk, type `/clear` and name the two languages again.

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
  it again, or type `/clear` and say the two languages again.

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

Everything stays on this computer. The translator does not use the internet and does not
save the conversation; closing the window clears it.

## 6. Where it comes from

- Model: [Qwen3-4B-Instruct-2507](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507)
  by the Qwen team, Apache License 2.0. The file on this drive is the Q4_K_M
  [GGUF version](https://huggingface.co/bartowski/Qwen_Qwen3-4B-Instruct-2507-GGUF).
- Engine: [llama.cpp](https://github.com/ggml-org/llama.cpp), MIT License (the same engine
  as the other AI launchers; see `HOW-TO-RUN-OFFLINE-AI`).
