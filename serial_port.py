import serial
import easygui

ser = serial.Serial()
ser.baudrate = 9600
ser.port = 'COM3'
print(ser)
ser.open()
print(ser.is_open)

while(1):
	start_stop = easygui.buttonbox(choices = ['Start/Stop','Reset','Quit'])
	
	#label_avr = ser.read(1)
	#print(label_avr)
	
	if start_stop == 'Quit':
		break
	if (start_stop == 'Start/Stop'):
		label_pc = b"1"
		ser.write(label_pc)
	# if (start_stop == 'Start/Stop') and (label_avr == 2):
		# label_pc = 2
		# ser.write(label_pc)
	if (start_stop == 'Reset'):
		label_pc = b"0"
		ser.write(label_pc)
	print(label_pc)
	