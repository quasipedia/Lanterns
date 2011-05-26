#define MINS_PAST r17
#define HOURS r18
/* SPI channel index */
#define SPI_CHINDEX r2
#define SPI_BYTE_TYPE r6
/* New data to send over SPI */
#define HAVE_NEW_DATA r3
/* 62.5Hz time counter */
#define REG_TICK_COUNTER	r20
#define REG_TICK_COUNTER_LOW	r20
#define REG_TICK_COUNTER_HIGH	r21
/*
 * Parameters to TLC functions
 */
#define REG_TLC_CHANNEL_NUMBER r10
#define REG_TLC_CHANNEL_INTENSITY_LOW r22
#define REG_TLC_CHANNEL_INTENSITY_HIGH r23

#define REG_I_CHANNEL_INDEX r19
/*
 * Used in TLC SPI Timer interrupt for storing current LED value
 * I in name stands for interrupt time variable
 */
#define REG_I_LED_CURRENT_LOW r24
#define REG_I_LED_CURRENT_HIGH r25

#define XL r26
#define XH r27
#define YL r28
#define YH r29
#define ZL r30
#define ZH r31

