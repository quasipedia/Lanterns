all: flash

AS = avr-as
ASFLAGS = -mmcu=atmega168

LD = avr-ld
LDFLAGS = -nostdlib

ledon.out: ledon.S
	avr-as -mmcu=atmega168 -o ledon.out ledon.S

main.o: main.s
tlc.o:	tlc.s

#	avr-as -mmcu=atmega168 -o main.o main.S

wordClock: main.o tlc.o
	avr-ld -nostdlib main.o tlc.o -o wordClock

ledon.hex: ledon.out
	avr-objcopy -O ihex ledon.out ledon.hex

wordClock.hex: wordClock
	avr-objcopy -O ihex wordClock wordClock.hex

flash: wordClock.hex
	avrdude -c usbasp -p m168 -P /dev/parport0 -U flash:w:wordClock.hex
