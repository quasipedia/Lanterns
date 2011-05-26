all: flash

CC = avr-gcc
AS = avr-as
#ASFLAGS = -mmcu=atmega168
#ASFLAGS = -Wa,mmcu=atmega168
LD = avr-ld
LDFLAGS = -nostdlib

main.o:	main.S
tlc.o:	tlc.S
tlcTest.o: tlcTest.S

tlcTest: tlcTest.o tlc.o
	avr-ld -nostdlib tlcTest.o tlc.o -o tlcTest

wordClock: main.o tlc.o
	avr-ld -nostdlib main.o tlc.o -o wordClock

wordClock.hex: wordClock
	avr-objcopy -O ihex wordClock wordClock.hex

tlcTest.hex: tlcTest
	avr-objcopy -O ihex tlcTest tlcTest.hex

tlctest-flash: tlcTest.hex
	avrdude -c avrisp -p m168 -P /dev/ -U flash:w:tlcTest.hex

flash: wordClock.hex
	avrdude -c usbasp -p m168 -P /dev/parport0 -U flash:w:wordClock.hex

clean:
	rm *~ *.o *.hex wordClock
