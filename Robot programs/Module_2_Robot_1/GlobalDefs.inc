'************************************************************
'*	 	  4-axis robot for the placement of parts			*
'*															*
'*				     	 KNIFE ASSY    Module 2				*
'*						 									*
'*						   Robot #1		    		        *
'*				       IP 192.168.0.31 						*
'*           DMI Industries Supplies © 2025			 		*					
'************************************************************

' ***********************
'   Macro Definitions
' ***********************

' Robot States

#define IDLE 0
#define INIT_ROBOT 1
#define START_AUTO_CYCLE 2
#define PICK_KNIFE_FROM_FEEDER 3
#define INSERT_LEFT_KNIFE 4
#define INSERT_RIGHT_KNIFE 5

#define CALCULATE_OFFSET 10
#define GET_OFFSET_VALUES 11
#define MANUAL_LOCK_JOINTS 12
#define MANUAL_FREE_JOINTS 13
#define MANUAL_RESET 14
#define MANUAL_GOTO_POS 15
#define MANUAL_DEBUG_CYCLE 16

' Reached positions

#define HOME_POS 1
#define TRAY_POS 8
#define APPROACH_PICKING_POS 2
#define APPROACH_INSERT_LH_POS 4
#define APPROACH_INSERT_RH_POS 6
#define PICK_POS 3
#define INSERT_LH_POS 5
#define INSERT_RH_POS 7

#define SAFE_Z -25
#define HIGH_SPEED 1
#define POWER_HIGH 1
#define POWER_LOW 0

#define PORT_FBIN_CONV_OFF_X IONumber("ConvOffset_X_L")
#define PORT_FBIN_CONV_OFF_Y IONumber("ConvOffset_Y_L")
#define PORT_FBIN_CONV_OFF_Z IONumber("ConvOffset_Z_L")
#define PORT_FBIN_CONV_OFF_U IONumber("ConvOffset_U_L")

#define PORT_FBIN_FEED_OFF_X IONumber("FeederOffset_X_L")
#define PORT_FBIN_FEED_OFF_Y IONumber("FeederOffset_Y_L")
#define PORT_FBIN_FEED_OFF_Z IONumber("FeederOffset_Z_L")
#define PORT_FBIN_FEED_OFF_U IONumber("FeederOffset_U_L")

#define PORT_FBOUT_OFF_X IONumber("Offset_X_L")
#define PORT_FBOUT_OFF_Y IONumber("Offset_Y_L")
#define PORT_FBOUT_OFF_Z IONumber("Offset_Z_L")
#define PORT_FBOUT_OFF_U IONumber("Offset_U_L")

#define CONVEYOR_OFFSET_SEL 0
#define FEEDER_OFFSET_SEL 1

#define TMR_CYCLE 0
#define TMR_DEBOUNCE 1

#define GRIPPER_OPEN_STATE 0
#define GRIPPER_CLOSE_STATE 10

#define SAFE_WAIT(Condition) Wait ((Condition) And (Sw(CycleProceed) Or MemSw(M_CycleProceed) Or Sw(DebugTrack)))

#define TASK_NOT_RUNNING 0
#define TASK_RUNNING 1
#define TASK_wAITING 2
#define TASK_HALTED 3
#define TASK_PAUSED 4
#define TASK_ERROR 5

'ERRORS
#define ERR_MOTION_AREA 8000

'FIELDBUS FAULT CODES
#define FAULT_SAFETY_AREA 1
