
;
; stoppuhr.asm
;
; Created: 13.03.2018 14:03:57
; Author : Zichong Lu
;

.nolist 
.include "m16adef.inc"
.list

;.def label = r26	; define r26 as the count/pause label, every time 
					; when the start/stop button is pressed, r26 will be 
					; judged. When r26 is 0x00, then it means the status of
					; pause; when it is 0xFF, it means the status of counting

.DSEG
.ORG 0x0060				; In SRAM at the address of 0x0060, we reserve 4 bytes for storing the 
table_stelle: .BYTE 4	; code of chip selection, to select which display should be on
.ORG 0x0070				; Similarly, at the address of 0x0070, 10 bytes for the code of segment
table_nummer: .BYTE 10	; selection, to display number


;.equ F_quarz = 4000000
;.equ baud = 9600
;.equ UBRR_VAL = F_quarz/(baud*16-1)


.CSEG
.org 0x0000
		rjmp main	

.org 0x002		; INT0, reset
		rjmp display_reset_init

.org 0x004		; INT1, start/stop
		rjmp mode_select_avr

.org 0x0010		; Interrupt vector of timer1 overflow
		rjmp timer1_overflow

.org 0x0016
		rjmp mode_select_pc

;================================================
;            Stack pointer initialize
;================================================


main:
		;Stackpointer initialize
		ldi r16, HIGH(RAMEND)
		out SPH, r16
		ldi r16, LOW(RAMEND)
		out SPL, r16
		
		ldi ZH, HIGH(table_stelle)		; Use Y and Z pointer to get the addresses of the lookup tables
		ldi ZL, LOW(table_stelle)


		ldi YH, HIGH(table_nummer)
		ldi YL, LOW(table_nummer)

;================================================
;               Write lookup table
;================================================
		ldi r16, 0xFA
		std Z+0, r16
		ldi r16, 0xF9
		std Z+1, r16
		ldi r16, 0xF3
		std Z+2, r16
		ldi r16, 0xEB
		std z+3, r16	
		
		ldi r16, 0xFD
		std Y+0, r16
		ldi r16, 0x19
		std Y+1, r16
		ldi r16, 0xD7
		std Y+2, r16
		ldi r16, 0x5F
		std Y+3, r16
		ldi r16, 0x2B
		std Y+4, r16
		ldi r16, 0x7E
		std Y+5, r16
		ldi r16, 0xFE
		std Y+6, r16
		ldi r16, 0x1D
		std Y+7, r16
		ldi r16, 0xFF
		std Y+8, r16
		ldi r16, 0x7F
		std Y+9, r16

;================================================
;               Output initialize
;================================================
output_init:

		clr r16

		ldi r16, 0xFF	; Port A and C are used as output ports, to light the display
		out DDRA, r16
		out DDRC, r16

		clr r16			; The external interrupt pins in port D are also set as output
		ldi r16, 0x0E
		out DDRD, r16
		sbi PORTD, 2
		sbi PORTD, 3


;================================================
;               UART initialize
;================================================
uart_init:
		cli

		ldi r16, 0x00
		out UCSRB, r16
		out UCSRC, r16

		;ldi r16, HIGH(UBRR_VAL)	; Set Baudrate
		;out UBRRH, r16
		ldi r16, 0x19
		out UBRRL, r16
		
			

		clr r16
		ldi r16, (1<<RXCIE)|(1<<RXEN)		
		out UCSRB, r16

		clr r16
		ldi r16, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
		out UCSRC, r16

;================================================
;           External interrupt initialize
; We use two external interrupt source INT0 and 
; INT1 for the Start/Stop and Reset of the Stopp-
; uhr. For both interrupt, we choose that the 
; falling edge generates the external interrupt
;================================================
exint_init:		
		cli
		clr r16
		ldi r16, 0x0A	; Refer to the register definition, 0x0A (00001010)  
		out MCUCR, r16	; represents the code of falling edge triggered 
						; external interrupt. According to the circuit plan
						; when the button of either "start/stop" or "reset" 
						; is pressed, the electric level at 2, 3 pin of port 
		ldi r16, 0xC0	; D will be pulled down (a falling edge). At this
		out GICR, r16	; time, the external interrupt will be triggered.
		out GIFR, r16


;================================================
;             Display reset (00:00)
;================================================
display_reset_init:

		ldi r26, 'A'

display_reset:
		
							; Here define r26 as a label, to tell which mode 
							; the CPU is running. At the beginning, when the 
		sei					; display is showing 00:00, we define it as mode 
							; A

		ldd r16, Z+3		; Read the number from the SRAM, and show them
		out PORTC, r16
		ldd r16, Y+0
		out PORTA, r16
		call delay_short	; After the definition of the external interrput
							; control registers, we enable all the interrupts
							; in this loop, to wait for the start/stop button 
		ldd r16, Z+2		; being pressed
		out PORTC, r16
		ldd r16, Y+0
		out PORTA, r16
		call delay_short

		ldd r16, Z+1
		out PORTC, r16
		ldd r16, Y+0
		out PORTA, r16
		call delay_short

		ldd r16, Z+0
		out PORTC, r16
		ldd r16, Y+0
		out PORTA, r16
		call delay_short

		rjmp display_reset
;================================================
;              Working mode selection
;           Control directly on the board
;================================================

mode_select_avr:												; Once the buttons are pressed, with the help of 
																; the interrupt vectors, the program will be lead
		cpi r26, 'A'											; to here: the running mode selection.
		breq jmp_display_count_init_avr

		cpi r26, 'B'
		breq jmp_display_pause_init_avr

		cpi r26, 'C'
		breq jmp_display_count_avr
		

jmp_display_count_init_avr:
		rjmp display_count_init


jmp_display_pause_init_avr:
		rjmp display_pause_init

jmp_display_count_avr:
		ldi r27, 0x04		
		out TIMSK, r27		; Open timer 1 again
		rjmp display_count

;================================================
;              Working mode selection
;               Control from the PC
;================================================
mode_select_pc:
		push r16
		in r16, UDR

status_pc:
		cpi r16, '1'
		breq status_avr
		cpi r16, '0'
		breq jmp_display_reset_pc


status_avr:
		cpi r26, 'A'		; Status of reset
		breq jmp_display_count_init_pc
		cpi r26, 'B'		; Status of counting
		breq jmp_display_pause_init_pc
		cpi r26, 'C'		; Status of pause
		breq jmp_display_count_pc
		cpi r26, 'D'
		breq jmp_display_count_init_pc


jmp_display_count_init_pc:
		pop r16
		rjmp display_count_init


jmp_display_pause_init_pc:
		pop r16
		rjmp display_pause_init

jmp_display_count_pc:
		pop r16
		ldi r27, 0x04		
		out TIMSK, r27		; Open timer 1 again
		rjmp display_count

jmp_display_reset_pc:
		pop r16
		ldi r26, 'D'
		rjmp display_reset

;================================================
;               Timer 0 initialize
;================================================

		;clr r16
		;ldi r16, 0x03
		;out TCCR0, r16

		;ldi r16, 0x01	; delay for 1ms
		;out TCNT0, r16
		
		;ldi r16, 0x01
		;out TIMSK, r16
;================================================
;          Display pause initialize
;================================================
display_pause_init:
		
		ldi r27, 0x00		; close timer 1
		out TIMSK, r27
		out TIFR, r27

;================================================
;               Display pause
;================================================
display_pause:
		

		cli

		ldi r26, 'C'
		
	
		ldd r16, Z+0
		out PORTC, r16
		out PORTA, r17
		call delay_short

		ldd r16, Z+1
		out PORTC, r16
		out PORTA, r18
		call delay_short

		ldd r16, Z+2
		out PORTC, r16
		out PORTA, r19
		call delay_short

		ldd r16, Z+3
		out PORTC, r16
		out PORTA, r20
		call delay_short

		sei

		rjmp display_pause



;================================================
;               Timer 1 initialize
;================================================
display_count_init:
		clr r16
		ldi r16, 0x03		; Even though timer1 is a 16 bit timer,
		out TCCR1B, r16     ; it is not enough to set time duration 
		                    ; as 1s. So the frequnecy has to be divided
							; in advanced. The prescaler is 64, that is 
							; why register TCCR1B is 0x03
		
		ldi r16, 0xF4		; Load the hex number of 62499 into register
		out TCNT1H, r16     ; TCNT1
		ldi r16, 0x23
		out TCNT1L, r16    

		ldi r16, 0x04       ; Interrupt enable, register TIMSK
		out TIMSK, r16
		ldi r26, 0x01
		ldi r16, 0x04       ; Set TOV1 in register TIFR as 1
		out TIFR, r16
			
		clr r16
		clr r17
		clr r18
		clr r19
		clr r20
		clr r22
		clr r23
		clr r24
		clr r25	

		ldi r26, 'B'

;================================================
;               Display count
; Display the counting of numbers
;================================================	

display_count:
		ldi r26, 'B'

		cli

		ldd r16, Z+0
		out PORTC, r16
		ldi YL, LOW(table_nummer)
		add YL, r22
		ld r17, Y
		out PORTA, r17
		call delay_short
		call delay_short
		call delay_short

		ldd r16, Z+1
		out PORTC, r16
		ldi YL, LOW(table_nummer)
		add YL, r23
		ld r18, Y
		out PORTA, r18
		call delay_short
		call delay_short
		call delay_short

		ldd r16, Z+2
		out PORTC, r16
		ldi YL, LOW(table_nummer)
		add YL, r24
		ld r19, Y
		out PORTA, r19
		call delay_short
		call delay_short
		call delay_short

		ldd r16, Z+3
		out PORTC, r16
		ldi YL, LOW(table_nummer)
		add YL, r25
		ld r20, Y
		out PORTA, r20
		call delay_short
		call delay_short
		call delay_short

		sei

		rjmp display_count

;================================================
;				timer1_overflow:
;================================================
timer1_overflow: 
		inc r22
		cpi r22, 0x0A
		breq inc_stelle2
		reti

inc_stelle2:
		clr r22
		inc r23
		cpi r23, 0x06
		breq inc_stelle3
		reti
		
inc_stelle3:
		clr r23
		inc r24
		cpi r24, 0x0A
		breq inc_stelle4
		reti

inc_stelle4:
		clr r24
		inc r25
		cpi r25, 0x06
		breq timer1_overflow
		reti
		

;================================================
;                 Short delay
; A short delay, used for display
;================================================
delay_short:
		ldi r21, 255	

L1:
		dec r21
		brne L1
		ret

