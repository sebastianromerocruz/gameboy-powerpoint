INCLUDE "assets/hardware.inc"
INCLUDE "assets/slides.asm"

SECTION "Header", ROM0[$100]

	jp EntryPoint

	ds $150 - @, 0 ; Make room for the header

EntryPoint:
	; Shut down audio circuitry
	ld a, 0
	ld [rNR52], a

	; Do not turn the LCD off outside of VBlank
WaitVBlank:
	ld a, [rLY]
	cp 144
	jr c, WaitVBlank

	; Turn the LCD off
	ld a, 0
	ld [rLCDC], a

	; Copy the tile data (shared by every slide)
	ld de, FontTiles
	ld hl, $9000
	ld bc, FontTiles.End - FontTiles
	call Memcpy

	; Initialize display registers
	ld a, %11100100
	ld [rBGP], a

	; Initialize input/slide state
	ld a, 0
	ld [wCurKeys], a
	ld [wNewKeys], a
	ld [wCurSlide], a

	; Load and reveal the first slide — same path every later transition uses
	call LoadSlide

; ---------------------------------------------------------------------------
; Main loop: wait for VBlank, poll input, advance/retreat the slide on an
; edge-triggered A/B press, then loop. The double wait (leave LY>=144, then
; re-enter it) guarantees exactly one UpdateKeys call per frame, even if the
; loop body runs faster than a full frame.
; ---------------------------------------------------------------------------
Main:
	ld a, [rLY]
	cp 144
	jp nc, Main
WaitVBlank2:
	ld a, [rLY]
	cp 144
	jp c, WaitVBlank2

	call UpdateKeys

	; A pressed? Advance to the next slide, unless already on the last one.
	ld a, [wNewKeys]
	and a, PAD_A
	jp z, CheckB
	ld a, [wCurSlide]
	cp a, NumSlides - 1
	jp z, CheckB
	inc a
	ld [wCurSlide], a
	call LoadSlide
	jp Main

; B pressed? Go back to the previous slide, unless already on the first one.
CheckB:
	ld a, [wNewKeys]
	and a, PAD_B
	jp z, Main
	ld a, [wCurSlide]
	cp a, 0
	jp z, Main
	dec a
	ld [wCurSlide], a
	call LoadSlide
	jp Main

; ---------------------------------------------------------------------------
; UpdateKeys: polls the joypad and writes wCurKeys (buttons currently held)
; and wNewKeys (buttons that just transitioned from up to down this frame).
; Straight from the gbdev.io Input chapter, this exact double-nibble dance
; is what the JOYP hardware requires; treat .onenibble as "trust me" for now.
; ---------------------------------------------------------------------------
UpdateKeys:
	; Poll half the controller
	ld a, JOYP_GET_BUTTONS
	call .onenibble
	ld b, a ; B7-4 = 1; B3-0 = unpressed buttons

	; Poll the other half
	ld a, JOYP_GET_CTRL_PAD
	call .onenibble
	swap a ; A7-4 = unpressed directions; A3-0 = 1
	xor a, b ; A = pressed buttons + directions
	ld b, a ; B = pressed buttons + directions

	; And release the controller
	ld a, JOYP_GET_NONE
	ld [rJOYP], a

	; Combine with previous wCurKeys to make wNewKeys
	ld a, [wCurKeys]
	xor a, b ; A = keys that changed state
	and a, b ; A = keys that changed to pressed
	ld [wNewKeys], a
	ld a, b
	ld [wCurKeys], a
	ret

.onenibble
	; writes the select bits you pass in (JOYP_GET_BUTTONS or 
	; JOYP_GET_CTRL_PAD) into the register. This tells the hardware which of 
	; the two 4-key groups to route onto bits 0-3.
	ld [rJOYP], a

	; it exists purely to spend ~10 cycles. This is the SM83/hardware 
	; equivalent of a debounce delay
	call .knownret

	; the first two are thrown away (still letting the matrix settle further)
	ld a, [rJOYP]
	ld a, [rJOYP]

	ld a, [rJOYP] ; this read counts

	; forces the upper nibble to all 1s and leaves the lower nibble (the actual
	; key states) untouched. Since unpressed = 1 and pressed = 0, this gives 
	; you a clean byte: 1111 in the top nibble (unused/don't-care), and the 
	; real pressed/unpressed bits in the bottom nibble.
	or a, $F0 ; A7-4 = 1; A3-0 = unpressed keys

.knownret
	; this returns twice — once from the call .knownret (immediately,
	; cycle-burning), and once for real at the end when .onenibble itself 
	; returns. Same ret instruction, two different callers.
	ret

; ---------------------------------------------------------------------------
; LoadSlide: looks up wCurSlide's tilemap pointer, blanks the BG map (so
; there's something to "type" onto), then reveals it via RevealCopy.
; ---------------------------------------------------------------------------
LoadSlide:
	ld a, [wCurSlide]
	add a, a
	ld l, a
	ld h, 0
	ld de, Slides
	add hl, de
	ld a, [hl+]
	ld e, a
	ld a, [hl]
	ld d, a ; de = address of the chosen SlideXMap

	ld a, 0
	ld [rLCDC], a ; safe: LoadSlide is only ever called during VBlank

	push de           ; stash the tilemap pointer while we blank
	ld hl, $9800
	ld bc, 32 * 18
.blank
	ld a, SPACE_TILE
	ld [hli], a
	dec bc
	ld a, b
	or a, c
	jr nz, .blank
	pop de

	ld a, LCDC_ON | LCDC_BG_ON
	ld [rLCDC], a

	ld hl, $9800
	ld bc, 32 * 18
	call RevealCopy
	ret

; Copies bc bytes from [de] to [hl], one byte at a time.
Memcpy:
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jr nz, Memcpy
	ret

; ---------------------------------------------------------------------------
; RevealCopy: identical to Memcpy, except it waits for a fresh VBlank before
; each byte. One tile revealed per frame — the "typewriter" effect. Blocks
; until the whole map is copied.
; ---------------------------------------------------------------------------
RevealCopy:
	ld a, [rLY]
	cp 144
	jp nc, RevealCopy   ; wait to leave the current VBlank
.wait
	ld a, [rLY]
	cp 144
	jp c, .wait         ; wait to re-enter the next one

	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jr nz, RevealCopy
	ret


SECTION "Input Variables", WRAM0

wCurKeys: db
wNewKeys: db
wCurSlide: db


SECTION "Slide Table", ROM0

Slides:
	dw Slide0Map, Slide1Map, Slide2Map, Slide3Map, Slide4Map, Slide5Map, Slide6Map, Slide7Map, Slide8Map, Slide9Map, Slide10Map, Slide11Map, Slide12Map, Slide13Map, Slide14Map, Slide15Map
.End:

def NumSlides equ (Slides.End - Slides) / 2

def SPACE_TILE equ 8 ; the ' ' glyph in FontTiles — used to blank the BG map before a reveal


SECTION "Tile data", ROM0

FontTiles:
	; tile 0 = 'C'
	db $78,$78, $c0,$c0, $c0,$c0, $c0,$c0, $c0,$c0, $c0,$c0, $78,$78, $00,$00
	; tile 1 = 'S'
	db $7c,$7c, $c0,$c0, $c0,$c0, $78,$78, $0c,$0c, $0c,$0c, $f8,$f8, $00,$00
	; tile 2 = 'U'
	db $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $78,$78, $00,$00
	; tile 3 = 'Y'
	db $cc,$cc, $cc,$cc, $78,$78, $30,$30, $30,$30, $30,$30, $30,$30, $00,$00
	; tile 4 = '-'
	db $00,$00, $00,$00, $00,$00, $fc,$fc, $00,$00, $00,$00, $00,$00, $00,$00
	; tile 5 = '2'
	db $78,$78, $cc,$cc, $0c,$0c, $18,$18, $30,$30, $60,$60, $fc,$fc, $00,$00
	; tile 6 = '1'
	db $30,$30, $70,$70, $30,$30, $30,$30, $30,$30, $30,$30, $78,$78, $00,$00
	; tile 7 = '4'
	db $18,$18, $38,$38, $58,$58, $98,$98, $fc,$fc, $18,$18, $18,$18, $00,$00
	; tile 8 = 'SPACE'
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	; tile 9 = 'O'
	db $78,$78, $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $78,$78, $00,$00
	; tile 10 = 'M'
	db $cc,$cc, $fc,$fc, $fc,$fc, $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $00,$00
	; tile 11 = 'P'
	db $f8,$f8, $cc,$cc, $cc,$cc, $f8,$f8, $c0,$c0, $c0,$c0, $c0,$c0, $00,$00
	; tile 12 = 'T'
	db $fc,$fc, $30,$30, $30,$30, $30,$30, $30,$30, $30,$30, $30,$30, $00,$00
	; tile 13 = 'E'
	db $fc,$fc, $c0,$c0, $c0,$c0, $f8,$f8, $c0,$c0, $c0,$c0, $fc,$fc, $00,$00
	; tile 14 = 'R'
	db $f8,$f8, $cc,$cc, $cc,$cc, $f8,$f8, $d0,$d0, $c8,$c8, $c4,$c4, $00,$00
	; tile 15 = 'A'
	db $78,$78, $cc,$cc, $cc,$cc, $fc,$fc, $cc,$cc, $cc,$cc, $cc,$cc, $00,$00
	; tile 16 = 'H'
	db $cc,$cc, $cc,$cc, $cc,$cc, $fc,$fc, $cc,$cc, $cc,$cc, $cc,$cc, $00,$00
	; tile 17 = 'I'
	db $fc,$fc, $30,$30, $30,$30, $30,$30, $30,$30, $30,$30, $fc,$fc, $00,$00
	; tile 18 = 'N'
	db $cc,$cc, $ec,$ec, $fc,$fc, $dc,$dc, $cc,$cc, $cc,$cc, $cc,$cc, $00,$00
	; tile 19 = 'D'
	db $f8,$f8, $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $f8,$f8, $00,$00
	; tile 20 = 'G'
	db $7c,$7c, $c0,$c0, $c0,$c0, $dc,$dc, $cc,$cc, $cc,$cc, $78,$78, $00,$00
	; tile 21 = 'Z'
	db $fc,$fc, $0c,$0c, $18,$18, $30,$30, $60,$60, $c0,$c0, $fc,$fc, $00,$00
	; tile 22 = 'F'
	db $fc,$fc, $c0,$c0, $c0,$c0, $f8,$f8, $c0,$c0, $c0,$c0, $c0,$c0, $00,$00
	; tile 23 = 'L'
	db $c0,$c0, $c0,$c0, $c0,$c0, $c0,$c0, $c0,$c0, $c0,$c0, $fc,$fc, $00,$00
	; tile 24 = '0'
	db $78,$78, $cc,$cc, $dc,$dc, $ec,$ec, $dc,$dc, $cc,$cc, $78,$78, $00,$00
	; tile 25 = '5'
	db $fc,$fc, $c0,$c0, $f8,$f8, $0c,$0c, $0c,$0c, $cc,$cc, $78,$78, $00,$00
	; tile 26 = '6'
	db $78,$78, $c0,$c0, $c0,$c0, $f8,$f8, $cc,$cc, $cc,$cc, $78,$78, $00,$00
	; tile 27 = '.'
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $30,$30, $30,$30, $00,$00
	; tile 28 = 'B'
	db $f8,$f8, $cc,$cc, $cc,$cc, $f8,$f8, $cc,$cc, $cc,$cc, $f8,$f8, $00,$00
	; tile 29 = 'J'
	db $3c,$3c, $0c,$0c, $0c,$0c, $0c,$0c, $cc,$cc, $cc,$cc, $78,$78, $00,$00
	; tile 30 = 'K'
	db $cc,$cc, $d8,$d8, $f0,$f0, $e0,$e0, $f0,$f0, $d8,$d8, $cc,$cc, $00,$00
	; tile 31 = 'Q'
	db $78,$78, $cc,$cc, $cc,$cc, $cc,$cc, $d4,$d4, $c8,$c8, $74,$74, $00,$00
	; tile 32 = 'V'
	db $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $78,$78, $78,$78, $30,$30, $00,$00
	; tile 33 = 'W'
	db $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $cc,$cc, $fc,$fc, $00,$00
	; tile 34 = 'X'
	db $cc,$cc, $cc,$cc, $78,$78, $30,$30, $78,$78, $cc,$cc, $cc,$cc, $00,$00
	; tile 35 = '3'
	db $f8,$f8, $0c,$0c, $38,$38, $0c,$0c, $0c,$0c, $cc,$cc, $78,$78, $00,$00
	; tile 36 = '7'
	db $fc,$fc, $0c,$0c, $18,$18, $30,$30, $60,$60, $60,$60, $60,$60, $00,$00
	; tile 37 = '8'
	db $78,$78, $cc,$cc, $cc,$cc, $78,$78, $cc,$cc, $cc,$cc, $78,$78, $00,$00
	; tile 38 = '9'
	db $78,$78, $cc,$cc, $cc,$cc, $7c,$7c, $0c,$0c, $0c,$0c, $78,$78, $00,$00
	; tile 39 = ','
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $30,$30, $60,$60, $00,$00
	; tile 40 = '%'
	db $c4,$c4, $c8,$c8, $10,$10, $20,$20, $40,$40, $98,$98, $8c,$8c, $00,$00
	; tile 41 = 'DIVIDER'
	db $00,$00, $00,$00, $00,$00, $ff,$ff, $ff,$ff, $00,$00, $00,$00, $00,$00
.End: