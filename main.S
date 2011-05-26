;; ****************************************************************************
;; Instead of string numbers we could use offsets into GS data, byte+
;; half byte; nybble address
;;
;; Registers
;;
;; r0 = scratch used by interrupt processor, don't use!
;; r1 = SPI reading, used in interrupt
;; r2 = SPI counter
;; r3 = have new gs data
;; r4l:r5h = LED brightness
;; r6 = TLC SPI Byte type
;; r7 = scratch used in interrupt processing
;; r10 = channel # parameter to TLC_setChannelTargetIntensity
;; r11: low byte of channel parameter
;; r12: high byte of channel parameter
;; r17 = minutes past hour
;; r18 = hours (0-11)
;; r19 = temp, can be overwritten by any function, but not overwritten
;;       in interrupt handlers
;; r20 = string nybble address for setting
;; r21 = scratch for interrupt handling
;; r24:r25 = timer counter
;; r26:r27 X, used in TLC_setChannelTargetIntensity.
;; r30:r31 Z = SPI read pointer
;;
;; Pins:
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
;;
;; Timers
;;
;; Timer0: Time handling. clock divider 1024
;; Timer2: TLC Handling. Clock divider 1024, max counter 3
;; ****************************************************************************


;; INCLUDES
.include "m168.h"
#include "reg_mnemonics.h"
.include "config.h"

;; CONSTANTS
;; TICKS_PER_STEP is the number of timer0 ticks per clock step.
;; For Erland's clock a clock step is five minutes, for Mac's it will be
;; one minute.
;; MINUTES_PER_STEP is defined in the relevant config.h file
;; 16000000 / (1024 * 255) timer ticks per second * 60 * 60
.equ	TICKS_PER_STEP, (16000000 * 60 * MINUTES_PER_STEP) / (1024 * 255)
.equ	STEPS_PER_HOUR, (60 / MINUTES_PER_STEP)
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
	rjmp TLC_spiInterrupt
.org INT_VECTORS_SIZE * 2

init:
	;; PORT SETUP
	;; set outputs before port direction, so values will be correct on
	;; switch
	call	TLC_init

	;; Initialize the time to midnight
	ldi 	MINS_PAST, 	0	; 5 minutes past hour
	ldi 	HOURS,		0	; hour

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

	/* clr r16	*/	/* Sets r16 to 0x00 */
	/* out PORTB, r16	*/	/* Sets portB outputs to 0? */
	/* out PORTD, r16	*/ /* Sets portD outputs to 0? */

loop:
	; Mac: Idle Sleep ??? isn't it ADC noise reduction ???
	; Erl: No. The lowest bit is SE (Sleep enable) the three bits above that
	;      are 0, which is idle sleep mode
	ldi 	r16,	1
	out	SMCR,	r16		; SMCR = Sleep mode control register
	sleep

doneSetting:
	;; Increment time counter if required
	;; Time counter is in r24, increased 62.5 times per second ==
	;; 18750 == 0x493e times per 5 minutes
	ldi	r16,	hi8( TICKS_PER_STEP )
	cli			; make sure r24 doesn't change while comparing
	cpi	r24,	lo8( TICKS_PER_STEP )	; compare with immediate
	cpc	r25,	r16			; compare with carry
	sei
	brmi	noNewTime		; branch if minus

	inc	MINS_PAST		; 5 minutes past the hour
	cli
	subi	r24, lo8( TICKS_PER_STEP )	; subtract immediate
	sbci	r25, hi8( TICKS_PER_STEP )	; subtract immediate with carry
	sei
	cpi	MINS_PAST, STEPS_PER_HOUR
	brlo	noNewHour		; branch if lower

	inc 	HOURS			; increment hour count
	cpi	HOURS, HOURS_PER_DAY
	brlo	noNewHour
	ldi 	HOURS, 0

noNewHour:
	;; Change time words if time changed
	;; If we get here, minutes changed, but not hours
	cpi	MINS_PAST, 0
	brne	isItTenPast
	;;
	;; call function to set all minute strings to intensity
	;;

isItTenPast:

noNewTime:
	/* Check buttons */
	/* Check LDR, adjust PWM */
	rjmp loop


timerInterrupt:
	/* save status byte */
	in	r0, 0x3f
	push	r0

	;; Incremement time counter (actual freq = 62.5Hz
	adiw 	r24, 1

doneSetting2:
	;;  restore status register
	pop	r0
	out	0x3f, r0
	reti

	;; 16 channels with 12 bits each = 24 bytes

initialGSValues:
	.byte	0b11111111 	; 15
	.byte	0b11111000
	.byte 	0b00000000
	.byte 	0b01000000	; 13
	.byte 	0b00000010
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

	;; There are 11 strings related to minutes
	;; this table has one word (16 bits) to indicate which strings are on
	;;
	;; LSB in each word is for string 3, bit 10 for string d
minuteStringData:
	.word	0x0000		   ; on the hour
	.word	0b0000000110000100 ; five past the hour
	.word	0b0000000110001000 ; ten past the hour
	.word	0b0000000110110000 ; quarter past the hour
	.word	0b0000000110000011 ; twenty past the hour
	.word   0b0000011001000100 ; twenty five past the hour
	.word   0b0000011000000000 ; half past
	.word   0b0000011110000100 ; 35 minutes past
	.word   0b0000000001000011 ; 40 minutes past
	.word   0b0000000111000000 ; 45 minutes past
	.word	0b0000000001001000 ; 50 minutes past
	.word   0b0000000001000100 ; 55 minutes past

	;; There are 16 strings related to hours
hourStringData:
	.word	0b0110000000000000 ; 12
	.word	0b0000000000000010 ;  1
	.word	0b0000000000000001 ;  2
	.word	0b0000000010000000 ;  3
	.word	0b0000000000001100 ;  4
	.word	0b0000000000010000 ;  5
	.word	0b0000001000000000 ;  6
	.word	0b0001000000000000 ;  7
	.word	0b0000000001100000 ;  8
	.word	0b1000000000000000 ;  9
	.word	0b0000000100000000 ; 10
	.word	0b0000110000000000 ; 11

.end
