import serial
import easygui

ser = serial.Serial()
ser.baudrate = 9600
ser.port = 'COM10'
print(ser)
ser.open()
print(ser.is_open)

while(1):
	start_stop = easygui.buttonbox(choices = ['Start/Stop','Reset','Quit'])

	if start_stop == 'Quit':
		break
	if (start_stop == 'Start/Stop'):
		label_pc = b"1"
		ser.write(label_pc)
	if (start_stop == 'Reset'):
		label_pc = b"0"
		ser.write(label_pc)
	print(label_pc)
	