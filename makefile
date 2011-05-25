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
	avrdude -c usbasp -p m168 -P /dev/parport0 -U flash:w:wordClock.hex

clean:
	rm *.o *.hex *.s wordClock
