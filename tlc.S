;; ****************************************************************************
;; Erl's code to drive one or more TLC5940 LED driver chips
;; In GNU Assembler for AVR ATMega168s
;;
;; Registers used:
;;   r0, r7, r8, r9 interrupt time scratch
;;   r2 = SPI Channel index
;;   r6 = SPI Byte type (0-2)
;;   r21, r22 scratch for interrupt handling
;;
;;   r24:r25	Scratch for interrupt handling
;;   r26:r27 = X Used interrupt time to index current values (but pushed)
;;   r28:r29 = Y Used interrupt time to index target values
;;   r30:r31 = Z Used in SPI to point into current
;; ****************************************************************************


;; INCLUDES
.include "m168.h"
.include "config.h"


;; REGISTER ALIASES
;; for this to work, the file must be passed through the C preprocessor,
;; which happens automatically if the file extension is ".S" instead of ".s"
#define SPI_CHINDEX	r2
#define SPI_BYTE_TYPE	r6


;; GLOBAL SYMBOLS for linking with other code
.global	TLC_init
.global TLC_spiInterrupt
.global TLC_spiTimerInterrupt


;; TLC5940 PIN DEFINITIONS
.equ	SCLK_PORT,	PORTB
.equ	SCLK_PIN,	5
.equ	XLAT_PORT,	PORTB
.equ	XLAT_PIN,	1
.equ	BLANK_PORT,	PORTB
.equ	BLANK_PIN,	2
.equ	DCPRG_PORT,	PORTD
.equ	DCPRG_PIN,	4
.equ	VPRG_PORT,	PORTD
.equ	VPRG_PIN,	7


.text

TLC_init:
	;; Init TLC5940 control pin values
	cbi	DCPRG_PORT, DCPRG_PIN
	cbi	VPRG_PORT, VPRG_PIN
	cbi	XLAT_PORT, XLAT_PIN

	;; Start display blanked until time has been set
	sbi	BLANK_PORT, BLANK_PIN

	;; PB4 = MISO is input, others output
	ldi	r16, 0xef
	out	DDRB, r16	; Set port B to all outputs, except MISO
	ser	r16		; Sets r16 to 0xff
	out	DDRD, r16	; Set port D to all outputs

	;; Enable SPI, set clock rate fck/2, idle low, data on rise
	ldi	r16, 0b11010000
	out	SPCR, r16
	out	SPSR, 1

	;; Setup timer 2 for SPI
	ldi	r16, 0b11000010	; Set OC2A on match, No OC2, CTC Mode
	sts	TCCR2A, r16

	ldi	r16, 0b00000111
	sts	TCCR2B, r16	; Select prescaler 1024, turn on

	ldi	r16, 3		; Conter top
	sts	OCR2A, r16

	ldi	r16,	0b00000010
	sts	TIMSK2, r16     ; Enable interrupt on compare A (OCIE2A bit)

	ldi	r16,	2
	mov	r3,	r16	; say that we want two updates of gs data,
	;; then just blanks

	cbi	BLANK_PORT, BLANK_PIN

	ret

;; Should send next byte if there is more data to be sent
TLC_spiInterrupt:
	in	r0, 0x3f
	push	r0
	push	r26		; push X register
	push	r27

	dec	SPI_CHINDEX
	brne	spiSendNext	; done!

	clr	r0		; r0 is saved blank bit
	;; Save blank bit.
	sbic	BLANK_PORT, BLANK_PIN ; skip next instruction if bit clear
	inc	r0		      ; ldi is invalid for register 0

	;; Sent last byte. Now make blank high to stop PWM, pulse XLAT,
	;; make blank low
	sbi	BLANK_PORT, BLANK_PIN
	;; XLAT pulse minimum duration is 20 ns. One clock @ 16 MHz is 62 ns.
	;; No problem.
	sbi	XLAT_PORT, XLAT_PIN
	cbi	XLAT_PORT, XLAT_PIN
	;; if blank was 0, then clear it
	sbrs	r0, 1		; Skip next instruction if bit in register set
	cbi	BLANK_PORT, BLANK_PIN

	rjmp	spiReturn

spiSendNext:
	;; SPI_CHINDEX contains index of byte to send.
	;;
	;; Byte 0: high byte of channel 0 intensity
	;; Byte 1: low nybble of channel 1 intensity, high nybble of channel 2
	;; Byte 2: low byte of channel 2
	;;
	;; Repeat
	;;
	;; Call Byte 0 type 2, Z points to high byte
	;; Call byte 1 type 1, Z points to low byte
	;; Call byte 2 type 0, Z points to high byte
	;;
	;; Current values stored in big endian byte format.
	;;
	;; Track byte type in one register, channel index in another, drop
	;; byte counter. Start with highest channel.

	cp	SPI_BYTE_TYPE,	0
	brne	nextByteTypeNot0

	lpm	r22,	Z+
	lsl	r22
	lsl	r22
	lsl	r22
	lsl	r22
	lpm	r7,	Z+
	lsr	r7
	lsr	r7
	lsr	r7
	lsr	r7
	or	r22,	r7

	;; next byte type will be 2
	ldi	r21,	2
	mov	SPI_BYTE_TYPE,	r21

	rjmp	sendByte

nextByteTypeNot0:
	cp	SPI_BYTE_TYPE,	1
	brne	nextByteTypeIs2
	;; Byte type is 1, Z points to low byte
	lpm	r22,	Z+
	;; Z now points to low byte
	andi	r22,	0xf0
	lpm	r7,	Z

	lsr	r7
	lsr	r7
	lsr	r7
	lsr	r7

	or	r22,	r7
	dec	SPI_BYTE_TYPE

	rjmp	sendByte

nextByteTypeIs2:
	lpm	r22,	Z+

	lsl	r22
	lsl	r22
	lsl	r22
	lsl	r22

	lpm	r7,	Z+

	lsr	r7
	lsr	r7
	lsr	r7
	lsr	r7

	or	r22, r7

	dec	SPI_BYTE_TYPE

sendByte:
	out	SPDR,	r22	; Initiates transmission

spiReturn:
	;;  restore status register
	pop	r27
	pop	r26
	pop	r0
	out	0x3f, r0

	reti

;;;
;;; If new data, initiate SPI transfer
;;; Else just pulse blank
;;;
TLC_spiTimerInterrupt:
	;; save status byte
	in	r0, 0x3f
	push	r0

	;; Check if any diffs are not zero
	;; X = r26:r27 current value
	;; Y = r28:r29 target value
	ldi	r26,	lo8( currentChannelValues )
	ldi	r27,	hi8( currentChannelValues )

	ldi	r28,	lo8( targetChannelValues )
	ldi	r29,	hi8( targetChannelValues )

	ldi	r19,	2 * 16 * NUMBER_TLC_CHIPS

	clr	r9		; R9 is change counter

checkDiffsLoop:
	ld	r24,	Y+	; Target Low byte
	ld	r0,	X+	; Current Low byte
	sub	r24,	r0	; r24 = r24 - r0

	ld	r25,	Y+	; Target Low byte
	ld	r0,	X+	; Current Low byte
	sbc	r25,	r0	; r25 = r25 - r0. r7:r8=diff

	brne	modify

doneModifying:
	dec	r19
	brne	checkDiffsLoop

	rjmp	allUpdated

modify:
	;; Update the current values and the diffs
	;; Minus status bit should be set here if the target is less than
	;; the current.
	brmi	decrease

	inc	r9
	sbiw	r26,	2	; r26=X Move x ptr back to value we just compared
	adiw	r24,	1
	st	X+,	r24
	st	X+,	r25

	rjmp	doneModifying

decrease:
	inc	r9
	sbiw	r26,	2	; Move x ptr back to value we just compared
	sbiw	r24,	1
	st	X+,	r24
	st	X+,	r25

	rjmp	doneModifying

allUpdated:
	tst	r9
	breq	allDiffsZero
	rjmp	startSending

allDiffsZero:
	;; No new grayscale data, just pulse blank
	sbi	BLANK_PORT, BLANK_PIN
	cbi	BLANK_PORT, BLANK_PIN
	rjmp	returnFromInterrupt

	;;
	;; Executed at interrupt time
	;;
startSending:
	dec	r3		; decrement counter of times to write

	ldi	r30,	lo8(currentChannelValues)
	ldi	r31,	hi8(currentChannelValues)

	ldi	r19,	16 * NUMBER_TLC_CHIPS
	mov	SPI_CHINDEX,	r19

	ldi	r19,	1	; Byte Type
	mov	r4,	r19

	lpm	r0,	Z
	out	SPDR,	r0	; Initiates transmission

returnFromInterrupt:
	;;  restore status register
	pop	r0
	out	0x3f, r0

	reti

;;;
;;; Actual API
;;;
;;; Parameters: channel number in r10, intensity in r11:r12
;;; Uses r10
;;;
TLC_setChannelTargetIntensity:
	.global TLC_setChannelTargetIntensity

	ldi	r26,	lo8( targetChannelValues )
	ldi	r27,	hi8( targetChannelValues )

	lsl	r10
	add	r26,	r10
	adc	r26,	0

	st	X+,	r11
	st	X+,	r12

	ret

	.data
	;;
	;; <number of channels> * 16 bits. (bits 15..x contain intensity sent
	;; to TLC. In other words, shift right 4 times to get value to be sent.
	;;
	.comm	currentChannelValues, (2 * 16 * NUMBER_TLC_CHIPS)

	;;
	;; 16 bit signed differences between desired value and current value
	;;
	.comm	targetChannelValues, 2 * 16 * NUMBER_TLC_CHIPS

	.end
