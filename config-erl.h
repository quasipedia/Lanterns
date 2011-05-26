	;;
	;; Matrix:
	;; K L O C K A N X Ä R
	;; 0 0 0 1 1 1 2   2 2
	;;
	;; X T J U G O F E M X
	;;   3 3 3 4 4 5 5 5
	;;
	;; T I O K V A R T X I
	;; 6 6 6 7 7 7 8 8   9
	;;
	;; X Ö V E R X H A L V
	;;   a a a b   c c c d
	;;
	;; T V Å E T T F Y R A
	;; e e e f f f10101011
	;;
	;; F E M Å T T A T R E
	;;12121213131314151515
	;;
	;; T I O S E X E L V A
	;;16161617171718181819
	;;
	;; S J U T O L V N I O
	;;1a1a1a1b1b1b1c1d1d1d
	;;
	;; Want structure to map minutes past the hour to strings to light
	;; 0 -> <none>
	;; 1 -> 5, a, b
	;; 2 -> 6, a, b
	;; 3 -> 7, 8, a, b
	;; 4 -> 3, 4, a, b
	;; 5 -> 5, 9, c, d
	;; 6 -> c, d
	;; 7 -> 5, a, b, c, d
	;; 8 -> 3, 4, 9
	;; 9 -> 7, 8, 9
	;; 10-> 6, 9
	;; 11-> 5, 9

.equ	NUMBER_TLC_CHIPS,	2
.global NUMBER_TLC_CHIPS

.equ    MINUTES_PER_STEP, 5
.equ    HOURS_PER_DAY, 12
