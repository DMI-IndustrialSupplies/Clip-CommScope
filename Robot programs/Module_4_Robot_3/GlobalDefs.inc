'************************************************************
'*	 	  4-axis robot for the placement of parts			*
'*															*
'*				    UNLOAD ASSY    Module 4					*
'*						 									*
'*						   Robot #3		    		        *
'*				       IP 192.168.0.33 						*
'*           DMI Industries Supplies © 2025			 		*					
'************************************************************

' ***********************
'   Macro Definitions
' ***********************

' Robot States

#define IDLE 0
#define INIT_ROBOT 1
#define START_AUTO_CYCLE 2
#define PICK_ASSY_FROM_NEST 3
#define PLACE_ASSY_ON_GOOD_FIELD 4
#define PLACE_ASSY_ON_SCRAP_FIELD 5

#define CALCULATE_OFFSET 10
#define GET_OFFSET_VALUES 11
#define MANUAL_LOCK_JOINTS 12
#define MANUAL_FREE_JOINTS 13
#define MANUAL_RESET 14
#define MANUAL_GOTO_POS 15

' Reached positions

#define HOME_POS 1
#define TRAY_POS 8
#define APPROACH_PICKING_POS 2
#define APPROACH_GOOD_BOX1_POS 4 'SPARE
#define APPROACH_SCRAP_POS 6 'SPARE
#define PICK_POS 3
#define GOOD_BOX1_POS 5
#define GOOD_BOX2_POS 9
#define SCRAP_POS 7

#define SAFE_Z 0
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

#define TMR_CYCLE 0
#define TMR_DEBOUNCE 1

#define GRIPPER_OPEN_STATE 0
#define GRIPPER_CLOSE_STATE 1

#define SAFE_WAIT(Condition) Wait (Condition And (Sw(CycleProceed) Or MemSw(M_CycleProceed)))

#define TASK_NOT_RUNNING 0
#define TASK_RUNNING 1
#define TASK_wAITING 2
#define TASK_HALTED 3
#define TASK_PAUSED 4
#define TASK_ERROR 5

'ERRORS'

#define ERR_MOTION_AREA 8000

'FIELDBUS FAULT CODES

#define FAULT_SAFETY_AREA 1

