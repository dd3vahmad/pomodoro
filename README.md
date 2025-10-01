# CSC204 PP | Pomodoro

## Overview

This is a practice project (PP) for the course CSC 204 - Assembly in x86, which I took in the second semester of my second year. The goal was to deepen my understanding of x86 assembly programming by building a functional Pomodoro timer as a TSR (Terminate-Stay-Resident) program in real-mode DOS. It hooks into keyboard (IRQ1) and timer (IRQ0) interrupts to create an interactive countdown timer with work/rest cycles.

Stay tuned—I'll be dropping a detailed article soon explaining the code step-by-step, the challenges I faced (like handling interrupt chaining and short jump ranges), how I solved them, and key learnings from the project. Watch out for it!

## Features

- **Countdown Timer**: Starts at 25 minutes for work sessions, decrements in ~55ms ticks using the hardware timer.
- **Modes**: Toggles between active work (25 min) and resting (short: 5 min or long: 15 min after every 4 cycles).
- **Controls**:
  - **S**, **C**, or **Space**: Start/toggle pause.
  - **P**: Pause/unpause.
  - **R**: Reset to 25:00:000.
- **Display**: Real-time update on VGA text mode (80x25 screen), showing MM:SS:MS format.
- **TSR**: Runs in the background as a memory-resident program.

## Prerequisites

- **DOSBox**: Emulator for running DOS programs (free and cross-platform).
- **NASM**: Netwide Assembler for compiling .asm to .com (download the DOS version and place `nasm.exe` in your project folder).
- Basic familiarity with command-line tools.

## Installation

1. Clone or download this repository.
2. Navigate to the project root (`cd pomodoro` or similar).
3. Copy the entire `pomodoro` folder to your home directory (or an accessible root-like location for DOSBox mounting). Use these OS-specific commands:

   **Ubuntu/Linux:**

   ```
   cp -r pomodoro ~
   ```

   **macOS:**

   ```
   cp -r pomodoro ~
   ```

   **Windows:**

   - Open Command Prompt as Administrator.
   - Run: `xcopy pomodoro C:\pomodoro /E /I` (creates `C:\pomodoro` with all files).
   - Alternatively, drag the `pomodoro` folder to `C:\` via File Explorer.

4. Download and install [DOSBox](https://www.dosbox.com/download.php?main=1) for your OS.
5. Download the DOS version of [NASM](https://www.nasm.us/pub/nasm/releasebuilds/2.16.01/win32/nasm-2.16.01.zip), extract `nasm.exe`, and copy it into your `pomodoro` folder (e.g., `~/pomodoro/nasm.exe` or `C:\pomodoro\nasm.exe`).

## Configuration

Configure DOSBox to mount your project folder as drive `C:`.

1. Launch DOSBox.
2. Run the configuration tool:

   - **Windows**: Go to the DOSBox installation folder and double-click `DOSBox 0.74 Options.bat` (opens `dosbox-0.74-3.conf` in Notepad).
   - **Ubuntu/Linux or macOS**: Run `dosbox -editconf` in terminal (opens the config file in your default editor).

3. At the end of the `[autoexec]` section, add these lines (adjust the path if your `pomodoro` folder is elsewhere):

   ```
   mount c ~/pomodoro
   c:
   ```

   - **Windows Note**: Use `mount c c:\pomodoro` (backslashes are fine in DOSBox config).

4. Save the file and restart DOSBox.

## How to Run

1. Start DOSBox (it should auto-mount `C:` to your `pomodoro` folder and switch to `C:` prompt).
2. Compile the assembly code:
   ```
   nasm pomodoro.asm -o pomodoro.com
   ```
3. Run the Pomodoro timer:
   ```
   pomodoro.com
   ```
   - The screen will clear and display: `MIN : S : MS` with `25 : 0 : 0`.
   - Press **S** (or **C**/**Space**) to start the countdown.
   - Use **P** to pause/unpause, **R** to reset.

To quit: Close DOSBox or reboot the emulated DOS (type `reboot` at prompt, but TSRs may persist—full restart recommended).

## Debugging

To step through the code assembly:

```
afd pomodoro.com
```

- This uses the DOS DEBUG utility (`debug.exe`—ensure it's in your DOSBox setup or mounted drive).
- Commands: `t` (trace), `g` (go), `q` (quit).

## Project Structure

- `pomodoro.asm`: Main assembly source code.
- `pomodoro.com`: Compiled executable (generated via NASM).
- `README.md`: This file.
- `dosbox.conf` (optional): Example config snippet—copy to your DOSBox setup if needed.

## Challenges & Learnings

(Teaser: Covered in upcoming article!)

- Interrupt handling in real-mode (e.g., chaining IRQs without breaking DOS input).
- Short jump range errors in NASM.
- Precise timing with ~55ms decrements for smooth countdown.
- VGA text mode manipulation for real-time display.

## License

MIT License—feel free to fork, modify, and learn!

---

_Built with ❤️ for assembly enthusiasts. Questions? Open an issue!_
