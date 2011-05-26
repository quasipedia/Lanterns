;; PINS:
;;
;; PB0 CLKO - TLC5940 GSCLK
;; PB1      - TLC5940 XLAT   0
;; PB2      - TLC5940 BLANK  1
;; PB3 MOSI - TLC5940 SIN
;; PB4 MISO - ArduinoISP
;; PB5 SCK  - TLC5940 SCLK   0
;; PB6 XTAL1 - Crystal
;; PB7 XTAL2 - Crystal
;; PD4       - TLC5940 DCPRG 0
;; PD7       - TLC5940 VPRG  1


;; INCLUDES
.include "m168.h"
.include "reg_mnemonics.h"

;; CONSTANTS
;;.equ	NUMBER_TLC_CHIPS,	1
;;.equ	MINUTES_PER_STEP, 	1
;;.equ	HOURS_PER_DAY, 	24
;;.equ	CURRENT_STRING,		r17

;; TICKS_PER_STEP is the number of timer0 ticks per clock step.
;; For Erland's clock a clock step is five minutes, for Mac's it will be
;; one minute.
;; MINUTES_PER_STEP is defined in the relevant config.h file
;; 16000000 / (1024 * 255) timer ticks per second * 60 * 60
.equ	TICKS_PER_STEP,	40
.equ	STRING_NUM,	34

;; GSDATA is the grayscale data. It consists of 32 12 bit values, packed into
;; 48 bytes. Channel 15 MSB first.
.equ	GSDATA,		0x0100



.text

;; INTERRUPT VECTORS, .org = advance location counter.
;; Since this code is the first to be excuted, the memory location is the
;; one for interrupts.
.org  0
	rjmp	init			;; boot & reset vector
.org OC2Aaddr * 2
	rjmp	TLC_spiTimerInterrupt
.org OVF0addr * 2
	rjmp	timerInterrupt	  	;; Timer 0 overflow
.org SPIaddr * 2
	rjmp 	TLC_spiInterrupt
.org INT_VECTORS_SIZE * 2

;; LED combos
ledCombos:
	.word	0b0000000000000000
	.word	0b0000000000000001
	.word	0b0000000000000010
	.word	0b0000000000000100
	.word	0b0000000000001000
	.word	0b0000000000010000
	.word	0b0000000000100000
	.word	0b0000000001000000
	.word	0b0000000010000000
	.word	0b0000000100000000
	.word	0b0000001000000000
	.word	0b0000010000000000
	.word	0b0000100000000000
	.word	0b0001000000000000
	.word	0b0010000000000000
	.word	0b0100000000000000
	.word	0b1000000000000000
	.word	0b1111111111111111
	.word	0b1111111111111110
	.word	0b1111111111111101
	.word	0b1111111111111011
	.word	0b1111111111110111
	.word	0b1111111111101111
	.word	0b1111111111011111
	.word	0b1111111110111111
	.word	0b1111111101111111
	.word	0b1111111011111111
	.word	0b1111110111111111
	.word	0b1111101111111111
	.word	0b1111011111111111
	.word	0b1110111111111111
	.word	0b1101111111111111
	.word	0b1011111111111111
	.word	0b0111111111111111

init:
	;; PORT SETUP
	;; set outputs before port direction, so values will be correct on
	;; switch
	call	TLC_init

	;; Initialize the led string to its first value
	ldi 	r17,	0

	;; Initialize timer tick counter
	ldi	r24, 	0
	ldi 	r25, 	0

	;; Set up timer 0 with 1024 prescaler
	clr	r16
	out	TCCR0A,	r16	; TCCR = timer/counter control register
	ldi	r16,	5
	out	TCCR0B, r16	; Select prescaler 1024, turn on
	ldi	r16,	1
	sts	TIMSK0, r16	; Enable interrupt on overflow (TOIE0 bit)

	;; Everything set up, enable interrupts
	sei			; Enable interrupts

loop:
	; Idle Sleep ??? isn't it ADC noise reduction ???
	ldi 	r16,	1		; ??? ADC noise reduction mode ???
	out	SMCR,	r16		; SMCR = Sleep mode control register
	sleep

doneSetting:
	;; Increment string counter if required
	;; Time counter is in r24, increased 62.5 times per second ==
	;; 18750 == 0x493e times per 5 minutes
	ldi	r16,	hi8( TICKS_PER_STEP )
	cli			; make sure r24 doesn't change while comparing
	cpi	r24,	lo8( TICKS_PER_STEP )	; compare with immediate
	cpc	r25,	r16			; compare with carry
	sei
	brmi	doNothing		; branch if minus

	;; if it's time for an update, cycle r17 through strings
	inc	r17			; change string to lit
	cpi	r17, 	STRING_NUM
	brmi	updateGSvalues
	ldi	r17,	0
	rjmp	updateGSvalues

doNothing:
	rjmp loop

timerInterrupt:
	in	r0, 0x3f		; save status byte
	push	r0
	adiw 	r24, 1			; counter++ []add immediate to word]
	pop	r0			; restore status register
	out	0x3f, r0
	reti				; return from interrupt

setGSon:
	ldi	r29,	0xf		; ldi needs r>16
	mov	r11,	r29
	mov	r12,	r29
	ret

setGSoff:
	ldi	r29,	0x0		; ldi needs r>16
	mov	r11,	r29
	mov	r12,	r29
	ret

updateGSvalues:
	;; Load the current string pattern
	ld	XL,	lo8( ledCombos )
	ld	XH,	hi8( ledCombos )
	adiw	X,	r17 * 2
	;; r10 = channel number, r29 = cycle counter
	ldi	r29,	0
	mov	r10,	r29		; ldi needs r>16

cycleChannels:
	inc	r29
	;; provisionally set the channel to OFF
	call setGSoff
	;; bitshift to right (carry in status register)
	lsr	r18
	;; if the channel is on, set channels accordingly
	brbs	SREG_C, setGSon
	;; call the API
	call	TLC_setChannelTargetIntensity
	cp	r29,	16
	brne	cycleChannels


;; 16 channels with 12 bits each = 24 bytes
GSValues:
	.byte	0	 	; 15
	.byte	0
	.byte 	0
	.byte 	0		; 13
	.byte 	0
	.byte 	0
	.byte 	0		; 11
	.byte 	0
	.byte 	0
	.byte 	0		; 9
	.byte 	0
	.byte 	0
	.byte 	0		; 7
	.byte 	0
	.byte 	0
	.byte 	0		; 5
	.byte 	0
	.byte 	0
	.byte 	0		; 3
	.byte 	0
	.byte 	0
	.byte 	0		; 1
	.byte 	0
	.byte 	0

.end
