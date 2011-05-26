all: flash

AS = avr-as
ASFLAGS = -mmcu=atmega168

LD = avr-ld
LDFLAGS = -nostdlib

main.o:	main.s
tlc.o:	tlc.s

wordClock: main.o tlc.o
	avr-ld -nostdlib main.o tlc.o -o wordClock

wordClock.hex: wordClock
	avr-objcopy -O ihex wordClock wordClock.hex

flash: wordClock.hex
#	avrdude -c avrisp -p m168 -P /dev/cu.usbserial-A6008gHF -b 19200 -U flash:w:wordClock.hex   # erl's
	avrdude -c usbasp -p m168 -P /dev/parport0 -U flash:w:wordClock.hex   # mac's

clean:
	rm *.o *.hex *.s wordClock simple

###############################################################################
# TEST PROGRAM SETTINGS BELOW #################################################
###############################################################################
simple.o: simple.s

simple: simple.o tlc.o
	avr-ld -nostdlib simple.o tlc.o -o simple

simple.hex: simple
	avr-objcopy -O ihex simple simple.hex

test: simple.hex
	avrdude -c usbasp -p m168 -P /dev/parport0 -U flash:w:simple.hex   # mac's
