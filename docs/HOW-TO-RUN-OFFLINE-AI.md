# Offline AI — Emergency Kit (No Internet Required)

This folder contains a complete, self-contained AI assistant that runs **100% offline**
on an ordinary computer — **no internet connection is needed**. It ships with **three
different AI models** so it works on anything from a weak laptop to a gaming PC:

- Two models run on **CPU + regular RAM only** (no graphics card needed at all).
- One extra model is tuned to run **GPU-accelerated on a ~6 GB graphics card** for speed.

Once this folder is on your drive, you never need the internet again to use it.

---

## 1. What's in this folder

```
E:\AI-Offline\
├─ CHAT-3B-light.bat     <- Double-click to chat (small, fast CPU model)
├─ CHAT-8B-smart.bat     <- Double-click to chat (bigger, smarter CPU model)
├─ CHAT-GPU-Qwen7B.bat   <- Double-click to chat (GPU-accelerated, ~6GB GPU)
├─ WEB-UI.bat            <- Chat in your web browser instead of a black window
├─ chat-*.sh, web-ui.sh  <- The same launchers for macOS / Linux
├─ engine\               <- The program that runs the AI (llama.cpp)
│   ├─ x64\              <- CPU engine for normal Intel/AMD computers
│   ├─ arm64\           <- CPU engine for ARM computers (Snapdragon / Surface Pro X)
│   ├─ vulkan-x64\      <- GPU engine (Vulkan) for graphics-card acceleration
│   ├─ macos-arm64\ macos-x64\                  <- engines for Macs (Apple Silicon / Intel)
│   └─ linux-x64\ linux-arm64\ linux-vulkan-x64\ <- engines for Linux (CPU / ARM / GPU)
├─ models\               <- The AI "brains" (the actual model files)
│   ├─ Llama-3.2-3B-Instruct-Q4_K_M.gguf        (~1.9 GB)  CPU, light
│   ├─ Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf   (~4.6 GB)  CPU, smarter
│   └─ Qwen2.5-7B-Instruct-Q4_K_M.gguf          (~4.4 GB)  GPU (6GB card)
└─ HOW-TO-RUN-OFFLINE-AI.(md/html/txt)   <- The documentation
```

- **engine** = the software (called *llama.cpp*). It is tiny and needs no installation.
  There is a **CPU** build (x64/arm64) and a **GPU** build (vulkan-x64).
  Every drive has the engine for **Windows, macOS and Linux**, so the AI runs on any of
  them, no matter which computer made the drive.
- **models** = the AI itself. These `.gguf` files hold everything the AI "knows."
  **Three** are included (see the table in section 3).
- The `.bat` files are one-click shortcuts that start everything for you.

---

## 2. Quick start (the easy way)

1. Open the `E:\AI-Offline` folder.
2. **Double-click `CHAT-3B-light.bat`** (works on almost any computer).
3. A black window opens. Wait a few seconds for the model to load.
4. When it says it's ready, **type a question and press Enter.**
5. The AI answers. Keep chatting. Press **Ctrl+C** (or close the window) to quit.

That's it. No setup, no accounts, no internet.

If your computer is reasonably powerful (8 GB RAM or more), try
**`CHAT-8B-smart.bat`** instead — it's noticeably smarter but a bit slower.

If your computer has a **graphics card with about 6 GB of memory or more**, use
**`CHAT-GPU-Qwen7B.bat`** — it runs on the GPU and is much faster. (If it errors with
an out-of-memory message, your GPU is too small; just use the CPU launchers instead.)

Prefer a nicer interface? **Double-click `WEB-UI.bat`**, wait until it says
"server listening," then open a web browser and go to **http://127.0.0.1:8080**.
This works offline too — it's a local page served by your own computer.

---

## 2b. On macOS / Linux

On a Mac or Linux computer, use the **`.sh`** launchers (every drive has them). Each one
picks the engine for the computer it runs on.
Open a terminal in the `AI-Offline` folder and run:

```
./chat-3B-light.sh        # fast, light model
./chat-8B-smart.sh        # smarter model
./web-ui.sh               # browser chat at http://127.0.0.1:8080
./chat-GPU-Qwen7B.sh      # GPU: Vulkan on Linux, Metal on a Mac
```

(If a script isn't executable: `chmod +x *.sh` first.) On macOS the AI automatically uses
the Mac's GPU (Metal) — no separate GPU launcher needed.

---

## 3. Which model should I use?

There are **three** models included, one for each kind of computer:

| Model (launcher) | Size | Runs on | Needs | Speed | Smartness |
|---|---|---|---|---|---|
| Llama-3.2-3B  (`CHAT-3B-light.bat`) | 1.9 GB | CPU | ~4 GB RAM | Fast | Good |
| Llama-3.1-8B  (`CHAT-8B-smart.bat`) | 4.6 GB | CPU | ~8 GB RAM | Slower | Better |
| Qwen2.5-7B  (`CHAT-GPU-Qwen7B.bat`) | 4.4 GB | **GPU** | ~6 GB VRAM | **Fastest*** | Better |

\* Fastest *when* it runs on a graphics card. On a 6 GB GPU the whole model fits in
video memory, so answers come back much quicker than on CPU.

Rule of thumb:
- **Old / low-spec / 4 GB RAM laptop, no decent GPU** → use the **3B** model (CPU).
- **Modern laptop or desktop, 8 GB+ RAM, no decent GPU** → use the **8B** model (CPU).
- **Has a graphics card with ~6 GB memory or more** → use the **Qwen 7B GPU** model.

The two CPU models need **no** graphics card at all. The GPU model needs a graphics
card but is much faster. If a GPU model won't fit your card, nothing breaks — just fall
back to a CPU launcher. A slow CPU only means slower answers; it will still work.

---

## 4. Running it manually (if the .bat files don't work)

You can run the AI by hand from a command prompt. This is useful if a shortcut
fails or you copied the folder somewhere else.

1. Press `Windows key`, type `cmd`, press Enter to open Command Prompt.
2. Paste this (adjust the drive/path if the folder is somewhere else):

   ```
   "E:\AI-Offline\engine\x64\llama-cli.exe" -m "E:\AI-Offline\models\Llama-3.2-3B-Instruct-Q4_K_M.gguf" -c 4096
   ```

3. Press Enter, wait for it to load, then type your message.

**On an ARM computer** (e.g. Surface Pro X, Snapdragon laptop), use the `arm64`
folder instead of `x64`:

   ```
   "E:\AI-Offline\engine\arm64\llama-cli.exe" -m "E:\AI-Offline\models\Llama-3.2-3B-Instruct-Q4_K_M.gguf" -c 4096
   ```

**On a computer with a graphics card (GPU acceleration)**, use the `vulkan-x64`
engine and add `-ngl 99` to push the model onto the GPU:

   ```
   "E:\AI-Offline\engine\vulkan-x64\llama-cli.exe" -m "E:\AI-Offline\models\Qwen2.5-7B-Instruct-Q4_K_M.gguf" -c 4096 -ngl 99
   ```

   If you get an out-of-memory / device error, your GPU can't fit all the layers:
   lower the number (e.g. `-ngl 20`) to offload only part of the model, or use a CPU
   engine instead. The Vulkan engine works on NVIDIA, AMD and Intel graphics cards.

Current llama-cli builds enter chat mode automatically for these instruction-tuned models.

### What the options mean
- `-m "...gguf"`  = which model (brain) file to load.
- `-c 4096`       = how much conversation it can remember at once (context size).
                    Lower this to `2048` if you run low on memory; raise it if you
                    have lots of RAM and want longer memory.
- `-ngl 99`       = (GPU only) how many model layers to put on the graphics card.
                    99 means "all of them." Lower it if the GPU runs out of memory.
- `-t 4`          = (optional) use 4 CPU threads. If left out, it auto-picks.
                    Set this to the number of CPU cores for best speed.

### Web interface by hand
   ```
   "E:\AI-Offline\engine\x64\llama-server.exe" -m "E:\AI-Offline\models\Llama-3.2-3B-Instruct-Q4_K_M.gguf" -c 4096 --host 127.0.0.1 --port 8080
   ```
   Then open **http://127.0.0.1:8080** in any browser.

---

## 5. Copying this to another computer

The whole thing is portable. To use it on a different PC with no internet:

1. Copy the **entire `AI-Offline` folder** (engine + models + .bat files) to the
   other computer — a USB stick or external drive works great.
2. Double-click a `.bat` file, or run the manual command above.

Because the model and the engine are both inside this folder, nothing else needs
to be installed. This is why it works in an emergency with no internet.

> Tip: Keep a copy on a USB flash drive (you'll need one that is at least 16 GB).
> The 3B model alone + engine fits on an 8 GB stick.

---

## 6. Troubleshooting

**"Windows protected your PC" / SmartScreen warning**
- Click **More info → Run anyway**. This happens because the file came from the
  internet. The llama.cpp engine is open-source and safe.

**A .bat window flashes and closes instantly**
- The model file may still be downloading or missing. Check that the three `.gguf`
  files exist in the `models` folder and are the full size (see the table above).
- Run the manual command in section 4 from a Command Prompt so you can read the
  error message (the window stays open).

**The GPU launcher (`CHAT-GPU-Qwen7B.bat`) errors or says out of memory**
- Your graphics card is too small to hold the whole model. Edit the .bat file and
  change `-ngl 99` to a smaller number (e.g. `-ngl 20`) to offload only part of it.
- Or just use a CPU launcher (`CHAT-3B-light.bat` / `CHAT-8B-smart.bat`) — they don't
  use the GPU at all and always work.
- No compatible GPU at all? Ignore the GPU launcher; the CPU ones are all you need.

**"not enough memory" / it crashes while loading**
- Use the smaller **3B** model.
- Lower the context: change `-c 4096` to `-c 2048`.
- Close other programs (browsers especially) to free RAM.

**It's very slow**
- That's normal on older CPUs, especially with the 8B model. Use the 3B model.
- Add `-t N` where N is your number of CPU cores (e.g. `-t 8`).

**The web UI page won't open**
- Make sure the `WEB-UI.bat` window is still open and says "server listening."
- Use exactly **http://127.0.0.1:8080** (not https).

**Which CPU build runs?**
- The engine ships several `ggml-cpu-*.dll` files and automatically picks the
  right one for your processor at startup. You don't need to choose.

---

## 7. Important notes & limitations

- **This AI runs entirely on your machine.** Nothing you type leaves the computer.
  No internet is used or needed once the files are in place.
- **Its knowledge is frozen** at the time the model was trained. It does not know
  about events after its training cutoff and cannot look things up online.
- **It can be wrong or make things up** ("hallucinate"). For an emergency, treat it
  as a knowledgeable helper, not an infallible authority — double-check anything
  safety-critical (medical, legal, survival) against printed references if possible.
- These are open-weight models (Meta Llama, Alibaba Qwen) distributed for free. The
  quantized `.gguf` files were produced by the community (bartowski) from the official
  models.

---

## 8. Technical summary (for reference)

- **Engine:** llama.cpp, one build for every system (its number is in `engine/BUILD.txt`).
  - CPU builds: `engine\x64` (Intel/AMD) and `engine\arm64` (ARM). No GPU needed.
  - GPU build: `engine\vulkan-x64` (Vulkan) — accelerates on NVIDIA/AMD/Intel GPUs,
    no CUDA install required.
  - macOS builds: `engine/macos-arm64` (Apple Silicon) and `engine/macos-x64` (Intel). They
    use the Mac's GPU (Metal) automatically.
  - Linux builds: `engine/linux-x64`, `engine/linux-arm64`, and `engine/linux-vulkan-x64` (GPU).
- **Format:** GGUF, Q4_K_M quantization (4-bit) — small size, good quality.
- **Models (3):**
  - Meta Llama 3.2 3B Instruct — general assistant, very light (CPU).
  - Meta Llama 3.1 8B Instruct — stronger general knowledge & reasoning (CPU).
  - Qwen 2.5 7B Instruct — strong all-rounder, sized to fit a ~6 GB GPU (GPU).
- **Source URLs (only needed if you ever want to re-download):**
  - Engine: https://github.com/ggml-org/llama.cpp/releases (the build named in `engine/BUILD.txt`)
  - 3B:  https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF
  - 8B:  https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF
  - 7B:  https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF

Stay safe. This kit is designed to keep working when nothing else does.
