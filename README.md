<h1 align=center>Gamebody Syllabus Powerpoint</h1>

<h3 align=center><em>A Syllabus Slideshow on Real Game Boy Hardware</em></h3>

<p align=center>
    <a href="https://gbdev.io/gb-asm-tutorial/part1/assembly.html"><img src="https://img.shields.io/badge/Language-gbZ80-494786"></img></a>
    <a href="https://rgbds.gbdev.io/"><img src="https://img.shields.io/badge/Toolchain-RGBDS-8bac0f"></img></a>
    <a href="https://emulicious.net/"><img src="https://img.shields.io/badge/Emulator-Emulicious-306230"></img></a>
    <a href="https://code.visualstudio.com/"><img src="https://img.shields.io/badge/IDE-VSCode-0098FF"></img></a>
</p>

A Game Boy ROM, hand-written in SM83 assembly (RGBDS), that turns the **CS-UY 2214: Computer Architecture and Organization** (NYU Tandon) syllabus into a 16-slide deck, navigated with the actual hardware A and B buttons on real or emulated hardware, each slide typewriter-revealed one tile per frame. Built to run live on an emulator on the first day of class. **A** advances to the next slide, **B** goes back.

<p align=center>
    <img src="assets/demo.gif"></img>
</p>

---

### _Sections_

1. [**Project Structure**](#project-structure)
2. [**Slides**](#slides)
3. [**Building**](#building)
4. [**Controls**](#controls)
5. [**Resources**](#resources)

---

### _Project Structure_

```
src/
├── assets
│   ├── hardware.inc ; standard RGBDS hardware register/constant definitions
│   └── slides.asm.  ; tilemap data for all 16 slides
└── syllabus.asm     ; entry point, main loop, input handling, slide loader, font tiles
```

<br>

### _Slides_

Title screen, course description, course objectives (parts one and two), logistics, contact, prerequisites, semester topics, grading rubric, assignments, getting help, tools, course schedule, class expectations, academic integrity, and inclusion.

<br>

### _Building_

Requires [**RGBDS**](https://rgbds.gbdev.io/).

```bash
cd src
rgbasm -L -o syllabus.o syllabus.asm
rgblink -o syllabus.gb -n syllabus.sym syllabus.o
rgbfix -v -p 0xFF syllabus.gb
```

Load the resulting `syllabus.gb` in [**Emulicious**](https://emulicious.net/) or any other Game Boy emulator (or flash it to a cartridge for the real thing).

<br>

### _Controls_

| Button | Action         |
|--------|----------------|
| A      | Next slide     |
| B      | Previous slide |

<br>

### _Resources_

- [**gb-asm-tutorial**](https://gbdev.io/gb-asm-tutorial/)" primary source for the underlying course
- [**Pan Docs**](https://gbdev.io/pandocs/): the Game Boy hardware bible
- [**RGBDS Documentation**](https://rgbds.gbdev.io/docs/)
- [**Emulicious**](https://emulicious.net/): emulator/debugger used throughout development
