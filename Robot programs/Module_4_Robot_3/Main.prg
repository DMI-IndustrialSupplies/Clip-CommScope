'************************************************************
'*	 	  4-axis robot for the placement of parts			*
'*															*
'*				   UNLOAD ASSY    Module 4					*
'*						 									*
'*						   Robot #3		    		        *
'*				       IP 192.168.0.33 						*
'*           DMI Industries Supplies © 2025			 		*					
'************************************************************

' ***********************
'        Includes
' ***********************
#include "GlobalDefs.inc"

' ***********************
'     Global Variables
' ***********************

Boolean InAutoMode, InManualMode, InCycle, InIDLE, ToolReturned, SubTaskActive, SpeedInitialized
Integer RobotState

' ***********************
'     Main Program
' ***********************
	
' ===== Function: main =====
' Purpose: main state machine. starts and dispatches states.
Function main
	
	Out FaultNum, 0
	Out WarningNum, 0
	InAutoMode = 0
	InManualMode = 0
	InCycle = 0
	InIDLE = 0
	ToolReturned = 0
	RobotState = IDLE
	
	If TaskState(F_SubTask) = TASK_NOT_RUNNING Then
		Xqt F_SubTask
	EndIf
	
	If TaskState(F_MonitorMotionArea) = TASK_NOT_RUNNING Then
		Xqt F_MonitorMotionArea, NoEmgAbort
	EndIf
	
	' Print start of main
	Print "Main: Start - entering main loop"

	Do While 1

		' ---------- Auto mode handling ----------
		If Sw(AutoMode) = 1 Or MemSw(M_AutoMode) = 1 Then
			
			InAutoMode = 1
			If (Sw(ToolReturnHome) = 0 And MemSw(M_ToolReturnHome) = 0) Then
				ToolReturned = 0 'Clear flag for another trigger
			EndIf
			If (Sw(CycleProceed) = 0 And MemSw(M_CycleProceed) = 0) Then
				InCycle = 0 'Clear flag for another trigger
			EndIf
			If Sw(ToolReturnHome) Or MemSw(M_ToolReturnHome) And ToolReturned = 0 Then
				Print "Main: Auto - ToolReturnHome triggered"
				RobotState = INIT_ROBOT
			ElseIf Sw(StartAutoSeq) Or MemSw(M_StartAutoSeq) Then
				If Sw(CycleProceed) Or MemSw(M_CycleProceed) And InCycle = 0 Then
					Print "Main: Check if robot is at home position"
					If AtHome Then
						Print "Main: Start Auto Cycle"
						RobotState = START_AUTO_CYCLE
					EndIf
				EndIf
			EndIf

		' ---------- Manual mode / HMI ----------
		ElseIf Sw(ManualMode) Or MemSw(M_ManualMode) Then
		
			InManualMode = 1
		'*************** HMI Button Commands ****************'
			If Sw(HMI_GoToManualPos) Then
				RobotState = MANUAL_GOTO_POS
			EndIf
			
			If Sw(HMI_LockJoints) Then
				Print "Main: HMI -> MANUAL_LOCK_JOINTS pressed"
				RobotState = MANUAL_LOCK_JOINTS
			EndIf
			
			If Sw(HMI_FreeJoints) Then
				Print "Main: HMI -> MANUAL_FREE_JOINTS pressed"
				RobotState = MANUAL_FREE_JOINTS
			EndIf
			
			If Sw(HMI_Reset) Then
				Print "Main: HMI -> MANUAL_RESET pressed"
				RobotState = MANUAL_RESET
			EndIf
			
			If (Sw(HMI_CalcOffset)) Then
				Print "Main: HMI -> CALCULATE_OFFSET pressed"
				RobotState = CALCULATE_OFFSET
			EndIf
			If (Sw(HMI_GetOffsets)) Then
				Print "Main: HMI -> UpdateOffsets pressed"
				RobotState = GET_OFFSET_VALUES
			EndIf
		EndIf
		
		If RobotState <> IDLE Then
			InIDLE = 0
		EndIf
		' ---------- State dispatch ----------
		Select RobotState
			
			Case IDLE
				
				'Do nothing...
				If InIDLE = 0 Then
					InCycle = 0
					Print "STATE: IDLE"
					InIDLE = 1
				EndIf
				
			Case INIT_ROBOT
				
				Print "STATE: INIT_ROBOT"
				InCycle = 0
				ToolReturned = 1
				Call F_InitRobot
				RobotState = IDLE
				
			Case START_AUTO_CYCLE
				
				Print "STATE: START_AUTO_CYCLE"
				InCycle = 1
				Call F_SetAutoMotionHigh
				RobotState = PICK_ASSY_FROM_NEST
				
			Case PICK_ASSY_FROM_NEST
				
				Print "STATE: PICK_ASSY_FROM_NEST"
				Call F_PickAssy
				' Do placement according to last module result
				If Sw(IsLastStationOK) Or MemSw(M_IsLastStationOK) Then
					Print "Main: Assy goes to Acceptance Field"
					RobotState = PLACE_ASSY_ON_GOOD_FIELD
				Else
					Print "Main: Assy goes to Scrap Field"
					RobotState = PLACE_ASSY_ON_SCRAP_FIELD
				EndIf
				
			Case PLACE_ASSY_ON_GOOD_FIELD
				
				Print "STATE: PLACE_ASSY_ON_GOOD_FIELD"
				Call F_PlaceAccepted
				RobotState = PICK_ASSY_FROM_NEST
				
			Case PLACE_ASSY_ON_SCRAP_FIELD
				
				Print "STATE: PLACE_ASSY_ON_SCRAP_FIELD"
				Call F_SetAutoMotionHigh
				Call F_PlaceScrap
				RobotState = PICK_ASSY_FROM_NEST
				
			Case CALCULATE_OFFSET
				
				Print "STATE: CALCULATE_OFFSET"
				Call F_CalculateOffset
				RobotState = IDLE
				
			Case GET_OFFSET_VALUES
				
				Print "STATE: GET_OFFSET_VALUES"
				Call F_GetOffsetValues
				RobotState = IDLE
				
			Case MANUAL_GOTO_POS
				
				Call F_Manual_GoToPos
				RobotState = IDLE
				
			Case MANUAL_LOCK_JOINTS
				
				Motor On
				RobotState = IDLE
				
			Case MANUAL_FREE_JOINTS
				
				SFree 1, 2, 3, 4
				RobotState = IDLE
				
			Case MANUAL_RESET
				
				Reset
				RobotState = IDLE
				
			Default
				Print "Main: Unknown state - quitting"
				Quit All
		Send
		
		Wait 0.01
	Loop
	
	Print "Main: Loop ended (unexpected)"
Fend

' ***********************
'      Functions
' ***********************

' ===== Function: F_Manual_GoToPos =====
' Purpose: Initiates movement to desired position at manual mode
Function F_Manual_GoToPos
	
	Byte ManualPos
	
	Print "F_Manual_GoToPos: Start"
	ManualPos = In(HMI_SetManualPos)
	
	If Sw(HMI_SetManualMotion) = HIGH_SPEED Then
		Call F_SetAutoMotionHigh
	Else
		Call F_SetAutoMotionLow
	EndIf
	
	If Sw(HMI_PowerLowHigh) = POWER_HIGH Then
		Power High
	Else
		Power Low
	EndIf
		
	If Sw(HMI_SafeMovement) Then
		F_SafeMovement(ManualPos)
	EndIf
	
	Select ManualPos
		
		Case HOME_POS
			
			Print "F_Manual_GoToPos: HMI -> Home pos selected"
			Call F_MoveToHome
			
		Case TRAY_POS
			
			Print "F_Manual_GoToPos: HMI -> Tray manual pos selected"
			Call F_MoveToTray
			
		Case APPROACH_PICKING_POS
			
			Print "F_Manual_GoToPos: HMI -> ApproachPick manual pos selected"
			Call F_MoveToApproachPick
			
		Case APPROACH_GOOD_BOX1_POS
			
			Print "F_Manual_GoToPos: HMI -> Approach Good Box 1 pos selected"

		Case APPROACH_SCRAP_POS
			
			Print "F_Manual_GoToPos: HMI -> Approach Scrap manual pos selected"

		Case PICK_POS
			
			Print "F_Manual_GoToPos: HMI -> Pick manual pos selected"
			Call F_MoveToPick
			
		Case GOOD_BOX1_POS
			
			Print "F_Manual_GoToPos: HMI -> Good Box 1 manual pos selected"
			Call F_MoveToPlace_GoodBox1
			
		Case GOOD_BOX2_POS
			
			Print "F_Manual_GoToPos: HMI -> Place Good Box 2 manual pos selected"
			Call F_MoveToPlace_GoodBox2
			
		Case SCRAP_POS
			
			Print "F_Manual_GoToPos: HMI -> PlaceScrap manual pos selected"
			Call F_MoveToPlace_Scrap
				
	Send
	Print "F_Manual_GoToPos: Done"
		
Fend

' ===== Function: F_ControlSpeedFactor =====
' Purpose: Sets system speed 
Function F_ControlSpeedFactor
	
	Print "F_ControlSpeedFactor: Start"
	SpeedFactor In(HMI_GlobalSpeed)
	Print "F_ControlSpeedFactor: Done"
	SpeedInitialized = 1
	
Fend


' ===== Function: F_SubTask =====
' Purpose: This task monitors and sets control speed factor. Also it handles the Operation cycle mode change 
Function F_SubTask
	
	Print "F_SubTask: Start"

	Do While 1
		
		Out RobotCurrentSpeed, SpeedFactor
		
		If Sw(HMI_SetSpeed) Or (SpeedInitialized = 0) Then
			Call F_ControlSpeedFactor 'Sets Global Speed at real time
		EndIf
		
		If RobotState <> IDLE Then
		
			If ((InAutoMode) And (Sw(AutoMode) = 0)) Or ((InManualMode) And (Sw(ManualMode) = 0)) Then

				InAutoMode = 0
				RobotState = IDLE
				Quit main
				Reset
				Xqt main
				
			EndIf
        
		EndIf
		
		Wait 0.1
	Loop
	Print "F_SubTask: Unexpected End"

Fend

' ===== Function: F_SetFault =====
' Purpose: sets fault code to fault number field
Function F_SetFault(FaultCode As Integer)
	Out FaultNum, FaultCode
	
Fend

Function F_MonitorMotionArea
	
	Wait GetRobotInsideBox(1) = 0
	F_SetFault(FAULT_SAFETY_AREA)
	Error ERR_MOTION_AREA
	Pause
    AbortMotion 1
    
Fend

' ===== Function: F_InitRobot =====
' Purpose: initialize robot, safe Z move, power sequence and go to home.
Function F_InitRobot
	
	Print "F_InitRobot: Start"
	Reset
	Call F_CloseGrip
	If Motor = Off Then
		Print "F_InitRobot: Turning motor ON"
		Motor On
	EndIf
	Print "F_InitRobot: Powering Low for safe move"
	Call F_SetHomeMotionLow
	Move Here :Z(SAFE_Z)
	Print "F_InitRobot: Powering High"
	Call F_SetHomeMotionHigh
	Call F_PlaceScrap
	Move P_Home :Z(SAFE_Z)
	Call F_MoveToHome
	
	Print "F_InitRobot: Done"
	
Fend

' ===== Function: F_SetHomeMotionLow =====
' Purpose: Set Speed and Acceleration Parameters for slow Home movement
Function F_SetHomeMotionLow
	Power Low
	SpeedS 80
	AccelS 70, 70
	Speed 80
   	Accel 70, 70
Fend
' ===== Function: F_SetHomeMotionHigh =====
' Purpose: Set Speed and Acceleration Parameters for fast Home movement
Function F_SetHomeMotionHigh
	Power High
	SpeedS 1000
	AccelS 4000, 4000
	Speed 100
   	Accel 100, 100
Fend
' ===== Function: F_SetAutoMotionHigh =====
' Purpose: Set Speed and Acceleration Parameters for Auto Cycle fast movement
Function F_SetAutoMotionHigh
	Power High
	SpeedS 2000
	AccelS 7500, 7500
	Speed 100
   	Accel 100, 100
Fend
' ===== Function: F_SetAutoMotionLow =====
' Purpose: Set Speed and Acceleration Parameters for Auto Cycle low movement
Function F_SetAutoMotionLow
	Power High
	SpeedS 1500
	AccelS 5000, 5000
	Speed 100
   	Accel 100, 100
Fend

' ===== Function: F_MoveToHome =====
' Purpose: move to home position and set reached pos flag.
Function F_MoveToHome
	
	Print "F_MoveToHome: Start"
	Move P_Home
	WaitPos
	Out ReachedPos, HOME_POS
	Print "F_MoveToHome: Home reached"
	
Fend

' ===== Function: F_MoveToTray =====
' Purpose: move to tray position and set reached pos flag.
Function F_MoveToTray
	
	Print "F_MoveToTray: Start"
	Move P_PlaceOnTray
	WaitPos
	Out ReachedPos, TRAY_POS
	Print "F_MoveToTray: Tray reached"
	
Fend

' ===== Function: F_MoveToApproachPick =====
' Purpose: go to approach pick position applying conveyor offset.
Function F_MoveToApproachPick
	
	Print "F_MoveToApproachPick: Start"
	Move P_AppPick + P_ConvOffset CP
	Out ReachedPos, APPROACH_PICKING_POS
	Print "F_MoveToApproachPick: Reached approach pick"
	
Fend

' ===== Function: F_MoveToPick =====
' Purpose: move to pick point (slow) applying conveyor offset.
Function F_MoveToPick
	
	Print "F_MoveToPick: Start"
	Out ReachedPos, PICK_POS
	Move P_Pick + P_ConvOffset
	Print "F_MoveToPick: Pick position reached"
	
Fend

' ===== Function: F_MoveToPlace_GoodBox1 =====
' Purpose: place good part in box 1.
Function F_MoveToPlace_GoodBox1
	
	Print "F_MoveToPlace_GoodBox1: Start"
	Move P_Place_GoodBox1
	WaitPos
	Out ReachedPos, GOOD_BOX1_POS
	Print "F_MoveToPlace_GoodBox1: Place good assy in box 1 done"
	
Fend
' ===== Function: F_MoveToPlace_GoodBox2 =====
' Purpose: place good part in box 2.
Function F_MoveToPlace_GoodBox2
	
	Print "F_MoveToPlace_GoodBox2: Start"
	Move P_Place_GoodBox2
	WaitPos
	Out ReachedPos, GOOD_BOX2_POS
	Print "F_MoveToPlace_GoodBox2: Place good assy in box 2 done"
	
Fend

' ===== Function: F_MoveToApproach_Scrap =====
' Purpose: place scrap part
Function F_MoveToPlace_Scrap
	
	Print "F_MoveToPlace_Scrap: Start"
	Move P_Place_Scrap
	WaitPos
	Out ReachedPos, SCRAP_POS
	Print "F_MoveToPlace_Scrap: Place scrap reached"
	
Fend

' ===== Function: F_SafeMovement =====
' Purpose: Moves to position through safe z trayectory
Function F_SafeMovement(Position As Byte)
	
	Move Here :Z(SAFE_Z)
	
	Select Position
		
		Case HOME_POS
		
			Move P_Home :Z(SAFE_Z)
			
		Case TRAY_POS
			
			Move P_PlaceOnTray :Z(SAFE_Z)
			
		Case APPROACH_PICKING_POS
			
			Move (P_AppPick + P_ConvOffset) :Z(SAFE_Z)
			
		Case PICK_POS
			
			Move (P_Pick + P_ConvOffset) :Z(SAFE_Z)
			
		Case GOOD_BOX1_POS
			
			Move (P_Place_GoodBox1) :Z(SAFE_Z)
			
		Case GOOD_BOX2_POS
			
			Move (P_Place_GoodBox2) :Z(SAFE_Z)
		
		Case SCRAP_POS
			
			Move (P_Place_Scrap) :Z(SAFE_Z)
		
	Send
Fend


' ===== Function: F_PickAssy =====
' Purpose: approach feeder, wait sensor, pick and retreat.
Function F_PickAssy
	
	Print "F_PickAssy: Start"
	Call F_SetAutoMotionHigh
	Move P_AppPick :Z(SAFE_Z) CP
	Call F_MoveToApproachPick
	Print "F_PickAssy: Waiting for Piece in Nest"
    SAFE_WAIT(((Sw(AssyPresent) And Sw(ConveyorStopped)) Or (MemSw(M_AssyPresent) And MemSw(M_ConveyorStopped))))
	Print "F_PickAssy: Sensor active - moving to pick"
	Call F_SetAutoMotionLow
	Call F_MoveToPick
	Call F_CloseGrip
	Print "F_PickAssy: Grip closed - retreating"
	Call F_MoveToApproachPick
	Call F_SetAutoMotionHigh
	Move P_AppPick :Z(SAFE_Z)
	Print "F_PickAssy: Done"
	
Fend

' ===== Function: F_OpenGrip =====
' Purpose: open gripper with debounce delays.
Function F_OpenGrip
	
	Print "F_OpenGrip: Open start"
	Off Gripper
	F_DebounceGripper(GRIPPER_OPEN_STATE)
	Print "F_OpenGrip: Open done"
	
Fend

' ===== Function: F_CloseGrip =====
' Purpose: close gripper with debounce delays.
Function F_CloseGrip
	
	Print "F_CloseGrip: Close start"
	On Gripper
	F_DebounceGripper(GRIPPER_CLOSE_STATE)
	Print "F_CloseGrip: Close done"
	
Fend

' ===== Function: F_DebounceGripper =====
' Purpose: Ensures that Gripper State is stable
Function F_DebounceGripper(Gripper_State As Boolean)
	
	TmReset TMR_DEBOUNCE
	Do While Tmr(TMR_DEBOUNCE) < 0.01
		If (Sw(GripperClosed) = 0 And Sw(GripperOpen) = 1 And Gripper_State = GRIPPER_OPEN_STATE) Or (Sw(GripperClosed) = 1 And Sw(GripperOpen) = 0 And Gripper_State = GRIPPER_CLOSE_STATE) Or (Sw(GripperClosed) = 0 And Sw(GripperOpen) = 0 And Gripper_State = GRIPPER_CLOSE_STATE) Then
			'Do nothing...
		Else
			TmReset (TMR_DEBOUNCE)
		EndIf
	Loop
Fend

' ===== Function: F_PlaceAccepted =====
' Purpose: Place assy in good part boxes 1 or 2 according to availablility
Function F_PlaceAccepted
	
	Boolean WaitingForAvailability
	WaitingForAvailability = 0
	Call F_SetAutoMotionHigh
	Print "F_PlaceAccepted: Start"
	
	If (Sw(GoodBox1Available) = 0 And Sw(GoodBox2Available) = 0) And (MemSw(M_GoodBox1Available) = 0 And MemSw(M_GoodBox2Available) = 0) Then
		
		Move P_Place_GoodBox1 :Z(SAFE_Z)
		Call F_MoveToPlace_GoodBox1
		WaitingForAvailability = 1
        SAFE_WAIT(((Sw(GoodBox1Available) Or Sw(GoodBox2Available)) Or (MemSw(M_GoodBox1Available) Or MemSw(M_GoodBox2Available))))
	EndIf
	
    If Sw(GoodBox1Available) Or MemSw(M_GoodBox1Available) Then
		
		Print "F_PlaceAccepted: Placing Assy in Box 1"
		If WaitingForAvailability Then
			WaitingForAvailability = 0
		Else
			Move P_Place_GoodBox1 :Z(SAFE_Z)
            Call F_MoveToPlace_GoodBox1
		EndIf
		Call F_OpenGrip
		Move P_Place_GoodBox1 :Z(SAFE_Z)
		
	ElseIf Sw(GoodBox2Available) Or MemSw(M_GoodBox2Available) Then
		
		Print "F_PlaceAccepted: Placing Assy in Box 2"
		If WaitingForAvailability Then
			Call F_MoveToPlace_GoodBox2
			WaitingForAvailability = 0
		Else
			Move P_Place_GoodBox2 :Z(SAFE_Z)
			Call F_MoveToPlace_GoodBox2
		EndIf
		Call F_OpenGrip
		Move P_Place_GoodBox2 :Z(SAFE_Z)
		
	EndIf
	Print "F_PlaceAccepted: Done"
	
Fend

' ===== Function: F_PlaceScrap =====
' Purpose: place assy in scrap field box
Function F_PlaceScrap
	
	Print "F_PlaceScrap: Start"
	Call F_SetAutoMotionHigh
	'Move P_App_Scrap :Z(SAFE_Z) CP
	Move P_Place_Scrap :Z(SAFE_Z)
	Print "F_PlaceScrap: Moving to place"
	Call F_MoveToPlace_Scrap
	If RobotState = INIT_ROBOT Then
		Wait(Sw(ScrapBoxAvailable) Or(MemSw(M_ScrapBoxAvailable)))
	Else
		SAFE_WAIT(((Sw(ScrapBoxAvailable) Or (MemSw(M_ScrapBoxAvailable)))))
	EndIf
	Call F_OpenGrip
	Move P_Place_Scrap :Z(SAFE_Z) CP
	'Move P_App_Scrap :Z(SAFE_Z) CP
	Move P_AppPick :Z(SAFE_Z) CP
	Print "F_PlaceScrap: Done"
	
Fend

' ===== Function: F_CalculateOffset =====
' Purpose: compute offset between current TCP and the selected base point; send via OutReal.
Function F_CalculateOffset
	
	Print "F_CalculateOffset: Start"
	
	' initialize temp'
	P_Adjustment = XY(0, 0, 0, 0)
	P_PositionToAdjust = XY(0, 0, 0, 0)
	P_Offset = XY(0, 0, 0, 0)
	
	Real Offset_X, Offset_Y, Offset_Z, Offset_U
	
	P_PositionToAdjust = P_Pick 'Offset for conveyor positions adjustment'
	
	Print "F_CalculateOffset: Reading current TCP position"
	P_Adjustment = Here
	Print "F_CalculateOffset: Calculating difference"
	P_Offset = P_Adjustment - P_PositionToAdjust
	Offset_X = CX(P_Offset)
	Offset_Y = CY(P_Offset)
	Offset_Z = CZ(P_Offset)
	Offset_U = CU(P_Offset)
	
	Print "F_CalculateOffset: Offset computed X=" + Str$(Offset_X) + " Y=" + Str$(Offset_Y) + " Z=" + Str$(Offset_Z) + " U=" + Str$(Offset_U)
	
	' Send Offset Values to PLC via Fieldbus Outputs (OutReal encodes to 2 WORDs)
	Print "F_CalculateOffset: Sending offsets to PLC (OutReal)"
	
	OutReal PORT_FBOUT_OFF_X, Offset_X
	OutReal PORT_FBOUT_OFF_Y, Offset_Y
	OutReal PORT_FBOUT_OFF_Z, Offset_Z
	OutReal PORT_FBOUT_OFF_U, Offset_U
	
	Print "F_CalculateOffset: Sent"
	
Fend

' ===== Function: F_GetOffsetValues =====
' Purpose: read offsets from PLC via InReal and update local Points.
Function F_GetOffsetValues
	
	Print "F_GetOffsetValues: Start - reading offsets from PLC"
	Real ConveyorOffset_X, ConveyorOffset_Y, ConveyorOffset_Z, ConveyorOffset_U
	
	'Get Both Offsets From Fieldbus Inputs'
	ConveyorOffset_X = InReal(PORT_FBIN_CONV_OFF_X)
	ConveyorOffset_Y = InReal(PORT_FBIN_CONV_OFF_Y)
	ConveyorOffset_Z = InReal(PORT_FBIN_CONV_OFF_Z)
	ConveyorOffset_U = InReal(PORT_FBIN_CONV_OFF_U)
	
	Print "F_GetOffsetValues: Read conveyor offsets: X=" + Str$(ConveyorOffset_X) + " Y=" + Str$(ConveyorOffset_Y) + " Z=" + Str$(ConveyorOffset_Z) + " U=" + Str$(ConveyorOffset_U)
	
	P_ConvOffset = XY(ConveyorOffset_X, ConveyorOffset_Y, ConveyorOffset_Z, ConveyorOffset_U) 'Offset Adjustment for Related Conveyor Points'
	
	Print "F_GetOffsetValues: Updated local Point variables"
	
Fend



