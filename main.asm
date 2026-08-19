INCLUDE "hardware.inc"

DEF BRICK_LEFT EQU $05
DEF BRICK_RIGHT EQU $06
DEF BLANK_TILE EQU $08
DEF DIGIT_OFFSET EQU $1A
DEF SCORE_TENS EQU $9870
DEF SCORE_ONES EQU $9871

SECTION "Header", ROM0[$100]

    jp EntryPoint

    ds $150 - @, 0 ; Make room for the header

EntryPoint:
    ; Do not turn the LCD off outside of VBlank
WaitVBlank:
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank

    ; Turn the LCD off
    ld a, 0
    ld [rLCDC], a

TitleScreen:
    ld de, Unbricked_Title_Screen_Tileset_Begin
    ld hl, $9000
    ld bc, Unbricked_Title_Screen_Tileset_End - Unbricked_Title_Screen_Tileset_Begin
    call MemCopy

    ld de, Unbricked_Title_Screen_Map_Begin
    ld hl, $9800
    ld bc, Unbricked_Title_Screen_Map_End - Unbricked_Title_Screen_Map_Begin
    call MemCopy

    ; Turn the LCD on
    ld a, LCDC_ON | LCDC_BG_ON
    ld [rLCDC], a

    ; During the first (blank) frame, initialize display registers
    ld a, %11100100
    ld [rBGP], a

TitleScreenLoop:
    call UpdateKeys
    ld a, [wCurKeys]
    and PAD_START
    jr z, TitleScreenLoop

    ; Turn the LCD off
    ld a, 0
    ld [rLCDC], a

    ; Copy the tile data
    ld de, Tiles
    ld hl, $9000
    ld bc, TilesEnd - Tiles
    call MemCopy

    ; Copy the tilemap
    ld de, Tilemap
    ld hl, $9800
    ld bc, TilemapEnd - Tilemap
    call MemCopy

    ; Copy the paddle tile
    ld de, Paddle
    ld hl, $8000
    ld bc, PaddleEnd - Paddle
    call MemCopy

    ; Copy the ball tile
    ld de, Ball
    ld hl, $8010
    ld bc, BallEnd - Ball
    call MemCopy

    ld a, 0
    ld b, 160
    ld hl, STARTOF(OAM)
ClearOam:
    ld [hli], a
    dec b
    jp nz, ClearOam

    ; Initialize the paddle sprite in OAM
    ld hl, STARTOF(OAM)
    ld a, 128 + 16
    ld [hli], a
    ld a, 16 + 8
    ld [hli], a
    ld a, 0
    ld [hli], a
    ld [hli], a
    ; Now initialize the ball sprite
    ld a, 100 + 16
    ld [hli], a
    ld a, 32 + 8
    ld [hli], a
    ld a, 1
    ld [hli], a
    ld a, 0
    ld [hli], a

    ; The ball starts out going up and to the right
    ld a, 1
    ld [wBallMomentumX], a
    ld a, -1
    ld [wBallMomentumY], a

    ; Turn the LCD on
    ld a, LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON
    ld [rLCDC], a

    ; During the first (blank) frame, initialize display registers
    ld a, %11100100
    ld [rBGP], a
    ld a, %11100100
    ld [rOBP0], a

    ; Initialize global variables
    ld a, 0
    ld [wCurKeys], a
    ld [wNewKeys], a
    ld [wScore], a

Main:
    ; Wait until it's *not* VBlank
    ld a, [rLY]
    cp 144
    jp nc, Main
WaitVBlank2:
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank2

    ; Add the ball's momentum to its position in OAM.
    ld a, [wBallMomentumX]
    ld b, a
    ld a, [STARTOF(OAM) + 5]
    add a, b
    ld [STARTOF(OAM) + 5], a

    ld a, [wBallMomentumY]
    ld b, a
    ld a, [STARTOF(OAM) + 4]
    add a, b
    ld [STARTOF(OAM) + 4], a

BounceOnTop:
    ; Remember to offset the OAM position!
    ; (8, 16) in OAM coordinates is (0, 0) on the screen.
    ld a, [STARTOF(OAM) + 4]
    sub a, 16 + 1
    ld c, a
    ld a, [STARTOF(OAM) + 5]
    sub a, 8
    ld b, a
    call GetTileByPixel ; Returns tile address in hl
    ld a, [hl]
    call IsWallTile
    jp nz, BounceOnRight
    call CheckAndHandleBrick
    ld a, 1
    ld [wBallMomentumY], a

BounceOnRight:
    ld a, [STARTOF(OAM) + 4]
    sub a, 16
    ld c, a
    ld a, [STARTOF(OAM) + 5]
    sub a, 8 - 1
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsWallTile
    jp nz, BounceOnLeft
    call CheckAndHandleBrick
    ld a, -1
    ld [wBallMomentumX], a

BounceOnLeft:
    ld a, [STARTOF(OAM) + 4]
    sub a, 16
    ld c, a
    ld a, [STARTOF(OAM) + 5]
    sub a, 8 + 1
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsWallTile
    jp nz, BounceOnBottom
    call CheckAndHandleBrick
    ld a, 1
    ld [wBallMomentumX], a

BounceOnBottom:
    ld a, [STARTOF(OAM) + 4]
    sub a, 16 - 1
    ld c, a
    ld a, [STARTOF(OAM) + 5]
    sub a, 8
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsWallTile
    jp nz, BounceDone
    call CheckAndHandleBrick
    ld a, -1
    ld [wBallMomentumY], a
BounceDone:

    ; First, check if the ball is low enough to bounce off the paddle.
    ld a, [STARTOF(OAM)]
    ld b, a
    ld a, [STARTOF(OAM) + 4]
    add a, 6
    cp a, b
    jp nz, PaddleBounceDone ; If the ball isn't at the same Y position as the paddle, it can't bounce.
    ; Now let's compare the X positions of the objects to see if they're touching.
    ld a, [STARTOF(OAM) + 5] ; Ball's X position.
    ld b, a
    ld a, [STARTOF(OAM) + 1] ; Paddle's X position.
    sub a, 8
    cp a, b
    jp nc, PaddleBounceDone
    add a, 8 + 16 ; 8 to undo, 16 as the width.
    cp a, b
    jp c, PaddleBounceDone

    ld a, -1
    ld [wBallMomentumY], a

PaddleBounceDone:

    ; Check the current keys every frame and move left or right.
    call UpdateKeys

    ; First, check if the left button is pressed.
CheckLeft:
    ld a, [wCurKeys]
    and a, PAD_LEFT
    jp z, CheckRight
Left:
    ; Move the paddle one pixel to the left.
    ld a, [STARTOF(OAM) + 1]
    dec a
    ; If we've already hit the edge of the playfield, don't move.
    cp a, 15
    jp z, Main
    ld [STARTOF(OAM) + 1], a
    jp Main

; Then check the right button.
CheckRight:
    ld a, [wCurKeys]
    and a, PAD_RIGHT
    jp z, Main
Right:
    ; Move the paddle one pixel to the right.
    ld a, [STARTOF(OAM) + 1]
    inc a
    ; If we've already hit the edge of the playfield, don't move.
    cp a, 105
    jp z, Main
    ld [STARTOF(OAM) + 1], a
    jp Main

; Copy bytes from one area to another.
; @param de: Source
; @param hl: Destination
; @param bc: Length
MemCopy:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or a, c
    jp nz, MemCopy
    ret

; Convert a pixel position to a tilemap address
; hl = $9800 + X + Y * 32
; @param b: X
; @param c: Y
; @return hl: tile address
GetTileByPixel:
    ; First, we need to divide by 8 to convert a pixel position to a tile position.
    ; After this we want to multiply the Y position by 32.
    ; These operations effectively cancel out so we only need to mask the Y value.
    ld a, c
    and a, %11111000
    ld l, a
    ld h, 0
    ; Now we have the position * 8 in hl
    add hl, hl ; position * 16
    add hl, hl ; position * 32
    ; Convert the X position to an offset.
    ld a, b
    srl a ; a / 2
    srl a ; a / 4
    srl a ; a / 8
    ; Add the two offsets together.
    add a, l
    ld l, a
    adc a, h
    sub a, l
    ld h, a
    ; Add the offset to the tilemap's base address, and we are done!
    ld bc, $9800
    add hl, bc
    ret

; @param a: tile ID
; @return z: set if a is a wall.
IsWallTile:
    cp a, $00
    ret z
    cp a, $01
    ret z
    cp a, $02
    ret z
    cp a, $04
    ret z
    cp a, $05
    ret z
    cp a, $06
    ret z
    cp a, $07
    ret

; Increase score by 1 and store it as a 1 byte packed BCD number
; changes A and HL
IncreaseScorePackedBCD:
    ld hl, wScore       ; load score address for faster access
    ld a, [hl]          ; load score to accumulator
    add 1
    daa                 ; make sure it's a BCD
    ld [hl], a          ; store score
    call UpdateScoreBoard
    ret

; Read the packed BCD score from wScore and updates the score display
UpdateScoreBoard:
    ld a, [wScore]      ; Get the Packed score
    and %11110000       ; Mask the lower nibble
    swap a              ; Move the upper nibble to the lower nibble (divide by 16)
    add a, DIGIT_OFFSET ; Offset + add to get the digit tile
    ld [SCORE_TENS], a  ; Show the digit on screen

    ld a, [wScore]      ; Get the packed score again
    and %00001111       ; Mask the upper nibble
    add a, DIGIT_OFFSET ; Offset + add to get the digit tile again
    ld [SCORE_ONES], a  ; Show the digit on screen
    ret

; Checks if a brick was collided with and breaks it if possible.
; @param hl: address of tile.
CheckAndHandleBrick:
    ld a, [hl]
    cp a, BRICK_LEFT
    jr nz, CheckAndHandleBrickRight
    ; Break a brick from the left side.
    ld [hl], BLANK_TILE
    inc hl
    ld [hl], BLANK_TILE
    call IncreaseScorePackedBCD
CheckAndHandleBrickRight:
    cp a, BRICK_RIGHT
    ret nz
    ; Break a brick from the right side.
    ld [hl], BLANK_TILE
    dec hl
    ld [hl], BLANK_TILE
    call IncreaseScorePackedBCD
    ret


Tiles:
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322222
	dw `33322222
	dw `33322222
	dw `33322211
	dw `33322211

	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111

	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222333
	dw `22222333
	dw `22222333
	dw `11222333
	dw `11222333

	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333

	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211

	dw `22222222
	dw `20000000
	dw `20111111
	dw `20111111
	dw `20111111
	dw `20111111
	dw `22222222
	dw `33333333

	dw `22222223
	dw `00000023
	dw `11111123
	dw `11111123
	dw `11111123
	dw `11111123
	dw `22222223
	dw `33333333

	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333

	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000

	dw `11001100
	dw `11111111
	dw `11111111
	dw `21212121
	dw `22222222
	dw `22322232
	dw `23232323
	dw `33333333

	; Paste your logo here!
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222211
	dw `22222211
	dw `22222211

	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111
	dw `11221111
	dw `11221111
	dw `11000011

	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11222222
	dw `11222222
	dw `11222222

	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222

	dw `22222211
	dw `22222200
	dw `22222200
	dw `22000000
	dw `22000000
	dw `22222222
	dw `22222222
	dw `22222222

	dw `11000011
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11000022

	dw `11222222
	dw `11222222
	dw `11222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222

	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222

	dw `22222222
	dw `22222200
	dw `22222200
	dw `22222211
	dw `22222211
	dw `22221111
	dw `22221111
	dw `22221111

	dw `11000022
	dw `00112222
	dw `00112222
	dw `11112200
	dw `11112200
	dw `11220000
	dw `11220000
	dw `11220000

	dw `22222222
	dw `22222222
	dw `22222222
	dw `22000000
	dw `22000000
	dw `00000000
	dw `00000000
	dw `00000000

	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11110022
	dw `11110022
	dw `11110022

	dw `22221111
	dw `22221111
	dw `22221111
	dw `22221111
	dw `22221111
	dw `22222211
	dw `22222211
	dw `22222222

	dw `11220000
	dw `11110000
	dw `11110000
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `22222222

	dw `00000000
	dw `00111111
	dw `00111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `22222222

	dw `11110022
	dw `11000022
	dw `11000022
	dw `00002222
	dw `00002222
	dw `00222222
	dw `00222222
	dw `22222222

        ; digits
        ; 0
        dw `33333333
        dw `33000033
        dw `30033003
        dw `30033003
        dw `30033003
        dw `30033003
        dw `33000033
        dw `33333333
        ; 1
        dw `33333333
        dw `33300333
        dw `33000333
        dw `33300333
        dw `33300333
        dw `33300333
        dw `33000033
        dw `33333333
        ; 2
        dw `33333333
        dw `33000033
        dw `30330003
        dw `33330003
        dw `33000333
        dw `30003333
        dw `30000003
        dw `33333333
        ; 3
        dw `33333333
        dw `30000033
        dw `33330003
        dw `33000033
        dw `33330003
        dw `33330003
        dw `30000033
        dw `33333333
        ; 4
        dw `33333333
        dw `33000033
        dw `30030033
        dw `30330033
        dw `30330033
        dw `30000003
        dw `33330033
        dw `33333333
        ; 5
        dw `33333333
        dw `30000033
        dw `30033333
        dw `30000033
        dw `33330003
        dw `30330003
        dw `33000033
        dw `33333333
        ; 6
        dw `33333333
        dw `33000033
        dw `30033333
        dw `30000033
        dw `30033003
        dw `30033003
        dw `33000033
        dw `33333333
        ; 7
        dw `33333333
        dw `30000003
        dw `33333003
        dw `33330033
        dw `33300333
        dw `33000333
        dw `33000333
        dw `33333333
        ; 8
        dw `33333333
        dw `33000033
        dw `30333003
        dw `33000033
        dw `30333003
        dw `30333003
        dw `33000033
        dw `33333333
        ; 9
        dw `33333333
        dw `33000033
        dw `30330003
        dw `30330003
        dw `33000003
        dw `33330003
        dw `33000033
        dw `33333333
TilesEnd:

Tilemap:
    db $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $1A, $1A, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $0B, $0C, $0D, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0E, $0F, $10, $11, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $12, $13, $14, $15, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $16, $17, $18, $19, $03, 0,0,0,0,0,0,0,0,0,0,0,0
    db $04, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
TilemapEnd:

Paddle:
    dw `13333331
    dw `30000003
    dw `13333331
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
PaddleEnd:

Ball:
    dw `00033000
    dw `00322300
    dw `03222230
    dw `03222230
    dw `00322300
    dw `00033000
    dw `00000000
    dw `00000000
BallEnd:

Unbricked_Title_Screen_Tileset_Begin:
	DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $00,$00, $00,$00, $00,$00, $01,$01, $03,$03, $07,$07, $06,$06, $0C,$0C
	DB $00,$00, $00,$00, $C0,$C0, $C0,$C0, $81,$81, $03,$03, $03,$03, $07,$07
	DB $00,$00, $00,$00, $00,$00, $C0,$C0, $C0,$C0, $81,$81, $01,$01, $03,$03
	DB $00,$00, $00,$00, $00,$00, $60,$60, $E0,$E0, $E0,$E0, $C1,$C1, $C3,$C3
	DB $00,$00, $00,$00, $60,$60, $63,$63, $CF,$CF, $8D,$8D, $81,$81, $03,$03
	DB $00,$00, $00,$00, $7C,$7C, $FE,$FE, $C3,$C3, $C3,$C3, $83,$83, $06,$06
	DB $00,$00, $00,$00, $01,$01, $07,$07, $07,$07, $02,$02, $02,$02, $04,$04
	DB $00,$00, $FC,$FC, $FE,$FE, $87,$87, $03,$03, $03,$03, $03,$03, $06,$06
	DB $00,$00, $00,$00, $00,$00, $01,$01, $01,$01, $03,$03, $06,$06, $06,$06
	DB $00,$00, $00,$00, $00,$00, $81,$81, $83,$83, $06,$06, $0C,$0C, $18,$18
	DB $00,$00, $00,$00, $70,$70, $C8,$C8, $08,$08, $08,$08, $18,$18, $30,$30
	DB $00,$00, $00,$00, $04,$04, $0C,$0C, $0C,$0C, $18,$18, $18,$18, $31,$31
	DB $00,$00, $00,$00, $00,$00, $00,$00, $06,$06, $3E,$3E, $F0,$F0, $C0,$C0
	DB $00,$00, $00,$00, $00,$00, $07,$07, $0E,$0E, $18,$18, $10,$10, $30,$30
	DB $00,$00, $00,$00, $FE,$FE, $FE,$FE, $01,$01, $03,$03, $07,$07, $01,$01
	DB $00,$00, $00,$00, $00,$00, $7C,$7C, $FF,$FF, $C3,$C3, $C1,$C1, $81,$81
	DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $80,$80, $80,$80
	DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $01,$01
	DB $18,$18, $38,$38, $30,$30, $60,$60, $60,$60, $C0,$C0, $C1,$C1, $81,$81
	DB $0E,$0E, $1E,$1E, $3C,$3C, $3C,$3C, $78,$78, $F0,$F0, $F0,$F0, $70,$70
	DB $07,$07, $0D,$0D, $09,$09, $19,$19, $11,$11, $31,$31, $61,$61, $63,$63
	DB $C2,$C2, $86,$86, $84,$84, $8C,$8C, $88,$88, $98,$98, $10,$10, $30,$30
	DB $07,$07, $06,$06, $0C,$0C, $0F,$0F, $1F,$1F, $10,$10, $20,$20, $60,$60
	DB $0E,$0E, $38,$38, $F0,$F0, $80,$80, $C0,$C0, $60,$60, $30,$30, $30,$30
	DB $04,$04, $08,$08, $08,$08, $30,$30, $3F,$3F, $3F,$3F, $70,$70, $70,$70
	DB $0E,$0E, $1C,$1C, $38,$38, $F0,$F0, $E0,$E0, $00,$00, $00,$00, $00,$00
	DB $0C,$0C, $18,$18, $18,$18, $30,$30, $60,$60, $60,$60, $C1,$C1, $C1,$C1
	DB $18,$18, $30,$30, $61,$61, $61,$61, $C0,$C0, $80,$80, $80,$80, $00,$00
	DB $30,$30, $E0,$E0, $C0,$C0, $80,$80, $01,$01, $01,$01, $03,$03, $06,$06
	DB $37,$37, $7C,$7C, $F8,$F8, $F0,$F0, $B0,$B0, $B0,$B0, $30,$30, $60,$60
	DB $00,$00, $00,$00, $00,$00, $00,$00, $01,$01, $01,$01, $03,$03, $03,$03
	DB $60,$60, $60,$60, $CF,$CF, $FF,$FF, $E0,$E0, $80,$80, $00,$00, $00,$00
	DB $03,$03, $03,$03, $86,$86, $86,$86, $0C,$0C, $0C,$0C, $18,$18, $18,$18
	DB $01,$01, $01,$01, $01,$01, $03,$03, $03,$03, $07,$07, $06,$06, $0E,$0E
	DB $80,$80, $80,$80, $80,$80, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $01,$01, $03,$03, $03,$03, $07,$07, $06,$06, $06,$06, $06,$06, $07,$07
	DB $82,$82, $06,$06, $0C,$0C, $18,$18, $10,$10, $31,$31, $61,$61, $C1,$C1
	DB $60,$60, $60,$60, $C1,$C1, $C1,$C1, $C3,$C3, $83,$83, $82,$82, $86,$86
	DB $C3,$C3, $83,$83, $83,$83, $83,$83, $03,$03, $03,$03, $03,$03, $03,$03
	DB $20,$20, $60,$60, $40,$40, $40,$40, $C1,$C1, $81,$81, $83,$83, $83,$83
	DB $40,$40, $C0,$C0, $80,$80, $80,$80, $80,$80, $01,$01, $07,$07, $FF,$FF
	DB $30,$30, $30,$30, $71,$71, $61,$61, $E3,$E3, $C2,$C2, $86,$86, $06,$06
	DB $D8,$D8, $98,$98, $8C,$8C, $0C,$0C, $06,$06, $06,$06, $03,$03, $03,$03
	DB $01,$01, $01,$01, $03,$03, $03,$03, $02,$02, $06,$06, $06,$06, $06,$06
	DB $83,$83, $83,$83, $06,$06, $06,$06, $06,$06, $06,$06, $06,$06, $07,$07
	DB $00,$00, $00,$00, $01,$01, $03,$03, $02,$02, $04,$04, $0C,$0C, $18,$18
	DB $86,$86, $8C,$8C, $0C,$0C, $18,$18, $18,$18, $10,$10, $30,$30, $30,$30
	DB $60,$60, $60,$60, $60,$60, $61,$61, $63,$63, $66,$66, $7C,$7C, $38,$38
	DB $06,$06, $06,$06, $8C,$8C, $8C,$8C, $08,$08, $18,$18, $1F,$1F, $1F,$1F
	DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $F8,$F8, $F8,$F8, $00,$00
	DB $38,$38, $30,$30, $30,$30, $60,$60, $60,$60, $41,$41, $C3,$C3, $CF,$CF
	DB $0C,$0C, $18,$18, $38,$38, $70,$70, $E0,$E0, $C0,$C0, $80,$80, $00,$00
	DB $03,$03, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $01,$01, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $86,$86, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $7C,$7C, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $FF,$FF, $80,$FF
	DB $03,$03, $01,$01, $00,$00, $00,$00, $00,$00, $00,$00, $FF,$FF, $01,$FF
	DB $F0,$F0, $C0,$C0, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $30,$30, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $18,$18, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $FC,$FC, $70,$70, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $80,$FF, $80,$FF, $80,$FF, $80,$FF, $80,$FF, $FF,$FF, $FF,$FF, $01,$FF
	DB $01,$FF, $01,$FF, $01,$FF, $01,$FF, $01,$FF, $FF,$FF, $FF,$FF, $80,$FF
	DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $FF,$FF, $01,$FF
	DB $80,$FF, $80,$FF, $80,$FF, $80,$FF, $80,$FF, $FF,$FF, $00,$00, $00,$00
	DB $01,$FF, $01,$FF, $01,$FF, $01,$FF, $01,$FF, $FF,$FF, $00,$00, $00,$00
	DB $00,$00, $00,$00, $00,$00, $00,$00, $03,$03, $03,$03, $03,$03, $03,$03
	DB $00,$00, $00,$00, $00,$00, $00,$00, $F0,$F0, $18,$18, $0C,$0C, $0C,$0C
	DB $00,$00, $00,$00, $00,$00, $00,$00, $03,$03, $06,$06, $0C,$0C, $0C,$0C
	DB $00,$00, $00,$00, $00,$00, $00,$00, $C0,$C0, $20,$20, $03,$03, $03,$03
	DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $06,$06, $06,$06
	DB $03,$03, $03,$03, $03,$03, $03,$03, $03,$03, $03,$03, $03,$03, $03,$03
	DB $0C,$0C, $0C,$0C, $18,$18, $F0,$F0, $00,$00, $00,$00, $00,$00, $00,$00
	DB $D8,$D8, $E1,$E1, $C3,$C3, $C3,$C3, $C3,$C3, $C3,$C3, $C3,$C3, $C1,$C1
	DB $F0,$F0, $98,$98, $0C,$0C, $0C,$0C, $FC,$FC, $00,$00, $00,$00, $84,$84
	DB $78,$78, $C4,$C4, $C0,$C0, $E0,$E0, $78,$78, $1C,$1C, $0C,$0C, $8C,$8C
	DB $0E,$0E, $07,$07, $03,$03, $00,$00, $00,$00, $00,$00, $00,$00, $08,$08
	DB $0F,$0F, $03,$03, $C3,$C3, $E3,$E3, $33,$33, $33,$33, $33,$33, $63,$63
	DB $C7,$C7, $08,$08, $00,$00, $00,$00, $07,$07, $0C,$0C, $0C,$0C, $0C,$0C
	DB $C3,$C3, $63,$63, $63,$63, $63,$63, $E3,$E3, $63,$63, $63,$63, $E3,$E3
	DB $7F,$7F, $86,$86, $06,$06, $06,$06, $06,$06, $06,$06, $06,$06, $06,$06
	DB $80,$80, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $C0,$C0, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $F8,$F8, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $78,$78, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $07,$07, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $C1,$C1, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $C7,$C7, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	DB $E3,$E3, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
Unbricked_Title_Screen_Tileset_End:

Unbricked_Title_Screen_Map_Begin:
	DB $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F, $10, $11, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $12, $13, $14, $15, $16, $17, $18, $19, $1A, $1B, $1C, $1D, $1E, $1F, $20, $21, $22, $23, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $24, $25, $26, $27, $28, $29, $2A, $2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $34, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $35, $36, $37, $35, $35, $38, $00, $00, $39, $3A, $3B, $3C, $00, $3D, $00, $3E, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $00, $00, $00, $00, $39, $3F, $40, $41, $00, $00, $00, $00, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $00, $00, $00, $39, $3F, $40, $3F, $40, $41, $00, $00, $00, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $00, $00, $39, $3F, $40, $3F, $40, $3F, $40, $41, $00, $00, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $00, $39, $3F, $40, $3F, $40, $3F, $40, $3F, $40, $41, $00, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $39, $3F, $40, $3F, $40, $3F, $40, $3F, $40, $3F, $40, $41, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $39, $3F, $40, $3F, $40, $3F, $40, $3F, $40, $3F, $40, $3F, $40, $41, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $42, $43, $42, $43, $42, $43, $42, $43, $42, $43, $42, $43, $42, $43, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $44, $45, $00, $00, $00, $00, $46, $47, $00, $00, $48, $00, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $49, $4A, $4B, $4C, $4D, $4D, $4E, $4F, $50, $51, $52, $53, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $35, $00, $54, $55, $56, $56, $57, $58, $59, $5A, $35, $53, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
	DB $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 0,0,0,0,0,0,0,0,0,0,0,0
Unbricked_Title_Screen_Map_End:

SECTION "Counter", WRAM0
wFrameCounter: db

SECTION "Ball Data", WRAM0
wBallMomentumX: db
wBallMomentumY: db

SECTION "Score", WRAM0
wScore: db
