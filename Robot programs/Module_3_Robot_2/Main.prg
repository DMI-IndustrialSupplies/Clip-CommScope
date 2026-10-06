'************************************************************
'*	 	  4-axis robot for the placement of parts			*
'*															*
'*				     CAP ASSY    Module 3					*
'*						 									*
'*						   Robot #2		    		        *
'*				       IP 192.168.0.32 						*
'*           DMI Industries Supplies © 2025			 		*					
'************************************************************

' ***********************
'        Includes
' ***********************
#include "GlobalDefs.inc"

' ***********************
'     	Globals
' ***********************

Boolean InAutoMode, InManualMode, InCycle, InIDLE, ToolReturned, SpeedInitialized
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
			If (Sw(ToolReturnHome) Or MemSw(M_ToolReturnHome)) And ToolReturned = 0 Then
				Print "Main: Auto - ToolReturnHome triggered"
				RobotState = INIT_ROBOT
			ElseIf Sw(StartAutoSeq) Or MemSw(M_StartAutoSeq) Then
				If (Sw(CycleProceed) Or MemSw(M_CycleProceed)) And InCycle = 0 Then
					Print "Main: Start Auto Cycle"
					If AtHome Then
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
			If (Sw(HMI_SaveOffsets)) Then
				Print "Main: HMI -> UpdateOffsets pressed"
				RobotState = GET_OFFSET_VALUES
			EndIf
		Else
			RobotState = IDLE
		EndIf

		
		If RobotState <> IDLE Then
			InIDLE = 0
		EndIf
		' ---------- State dispatch ----------
		Select RobotState
			
			Case IDLE
				
				If InIDLE = 0 Then
					Print "STATE: IDLE"
					InCycle = 0
					InIDLE = 1
				EndIf
				'Do nothing...
				
			Case INIT_ROBOT
				
				Print "STATE: INIT_ROBOT"
				InCycle = 0
				ToolReturned = 1
				Call F_InitRobot
				Print "********** Set State(1) to IDLE **********"
				RobotState = IDLE
				
			Case START_AUTO_CYCLE
				
				Print "STATE: START_AUTO_CYCLE"
				InCycle = 1
				Call F_SetAutoMotionHigh
				RobotState = PICK_CLIP_FROM_FEEDER
				
			Case PICK_CLIP_FROM_FEEDER
				
				Print "STATE: PICK_CLIP_FROM_FEEDER"
				Call F_PickClipFromFeeder
				RobotState = F_GetRequirement
				
			Case INSERT_LEFT_CLIP
				
				Print "STATE: INSERT_LEFT_CLIP"
				Call F_PlaceLeftClip

				RobotState = PICK_CLIP_FROM_FEEDER
				
			Case INSERT_RIGHT_CLIP
				
				Print "STATE: INSERT_RIGHT_CLIP"
				Call F_PlaceRightClip
				
				RobotState = PICK_CLIP_FROM_FEEDER
				
			Case CALCULATE_OFFSET
				
				Print "STATE: CALCULATE_OFFSET"
				Call F_CalculateOffset
				RobotState = IDLE
				Print "********** Set State(2) to IDLE **********"
				
			Case GET_OFFSET_VALUES
				
				Print "STATE: GET_OFFSET_VALUES"
				Call F_GetOffsetValues
				RobotState = IDLE
				Print "********** Set State(3) to IDLE **********"
				
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
		
		If RobotState = IDLE Then
			Wait 0.01
		EndIf
		
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
			Call F_MoveToApproachPickCLip1
			
		Case APPROACH_INSERT_LH_POS
			
			Print "F_Manual_GoToPos: HMI -> ApproachLeft manual pos selected"
			Call F_MoveToApproach_LeftClip
			
		Case APPROACH_INSERT_RH_POS
			
			Print "F_Manual_GoToPos: HMI -> ApproachRight manual pos selected"
			Call F_MoveToApproach_RightClip
			
		Case PICK_POS
			
			Print "F_Manual_GoToPos: HMI -> Pick pressed"
			Call F_MoveToPickClip1
			
		Case INSERT_LH_POS
			
			Print "F_Manual_GoToPos: HMI -> PlaceLeft manual pos selected"
			Call F_MoveToPlace_LeftClip
			
		Case INSERT_RH_POS
			
			Print "F_Manual_GoToPos: HMI -> PlaceRight manual pos selected"
			Call F_MoveToPlace_RightClip
				
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
	
	Wait GetRobotInsideBox(1) = 0 Or GetRobotInsideBox(2) = 1 Or GetRobotInsideBox(3) = 1

	F_SetFault(FAULT_SAFETY_AREA)
	Error ERR_MOTION_AREA
	Pause
    AbortMotion 1
    
    
Fend

' ===== Function: F_InitRobot =====
' Purpose: initialize robot, safe Z move, power sequence and go to home.
Function F_InitRobot
	
	Print "F_InitRobot: Start"
	Call F_CloseGrip
	Reset
	
	If Motor = Off Then
		Print "F_InitRobot: Turning motor ON"
		Motor On
	EndIf
	Call F_SetHomeMotionLow
	Print "F_InitRobot: Powering Low for safe move"
	Move Here :Z(SAFE_Z)
	Print "F_InitRobot: Powering High"
	Call F_SetHomeMotionHigh
	Move P_PlaceOnTray :Z(SAFE_Z)
	Call F_MoveToTray
	Call F_OpenGrip
	Move P_PlaceOnTray :Z(SAFE_Z)
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
	AccelS 18000, 18000
	Speed 100
   	Accel 100, 100
Fend
' ===== Function: F_SetAutoMotionLow =====
' Purpose: Set Speed and Acceleration Parameters for Auto Cycle low movement
Function F_SetAutoMotionLow
	Power High
	SpeedS 1000
	AccelS 5000, 5000
	Speed 100
   	Accel 100, 100
Fend
' ===== Function: F_AllowRotationMotion =====
' Purpose: Set Speed and Acceleration Parameters for Tool Rotation
Function F_AllowRotationMotion
	Power High
	SpeedR 1000
	AccelR 5000
Fend

' ===== Function: F_GetRequirement =====
' Purpose: Waits for place requirement if there is none and intercepts
' new instruction in order to change robot state to placing

Function F_GetRequirement
	
	Boolean WaitingForRequirement
	WaitingForRequirement = 0
	Print "F_GetRequirement: Start"
	Call F_SetAutoMotionHigh
	
	If (Sw(LhClipRequired) = 0 And MemSw(M_LhClipRequired) = 0) And (Sw(RhClipRequired) = 0 And MemSw(M_RhClipRequired) = 0) Then
		
		'Move P_App_RightClip :Z(SAFE_Z)
		Jump P_App_RightClip LimZ (SAFE_Z)
		Call F_MoveToApproach_RightClip
		WaitingForRequirement = 1
		Print "F_GetRequirement: Waiting for requirement"
		SAFE_WAIT(((Sw(LhClipRequired) <> 0 Or MemSw(M_LhClipRequired) <> 0) Or (Sw(RhClipRequired) <> 0 Or MemSw(M_RhClipRequired) <> 0)))
	
	EndIf
	
	' Decide placement side based on sensors
	If Sw(LhClipRequired) = 1 Or MemSw(M_LhClipRequired) = 1 Then
	
		Print "F_GetRequirement: left clip placement needed"
		If WaitingForRequirement Then
			WaitingForRequirement = 0
		Else
			'Move P_App_LeftClip :Z(SAFE_Z)
			Jump P_App_LeftClip LimZ (SAFE_Z)
			
		EndIf
		
		Call F_MoveToApproach_LeftClip
		F_GetRequirement = INSERT_LEFT_CLIP
		
	ElseIf Sw(RhClipRequired) = 1 Or MemSw(M_RhClipRequired) = 1 Then
		
		Print "F_GetRequirement: right clip placement needed"
		If WaitingForRequirement Then
			WaitingForRequirement = 0
		Else
			'Move P_App_RightClip :Z(SAFE_Z)
			Jump P_App_RightClip LimZ (SAFE_Z)
			Call F_MoveToApproach_RightClip
		EndIf
		
		F_GetRequirement = INSERT_RIGHT_CLIP
			
	EndIf
	
	Print "F_GetRequirement: New requirement triggered"
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

' ===== Function: F_MoveToApproachPickCLip =====
' Purpose: go to approach pick position applying feeder offset.
Function F_MoveToApproachPickCLip1
	
	Print "F_MoveToApproachPickCLip1: Start"
	Move P_AppPickCLip1 + P_FeederOffset CP
	Out ReachedPos, APPROACH_PICKING_POS
	Print "F_MoveToApproachPickCLip1: Reached approach pick"
	
Fend

' ===== Function: F_MoveToApproachPickCLip2 =====
' Purpose: go to approach pick position applying feeder offset.
Function F_MoveToApproachPickCLip2(AllowRotation As Boolean)
	
	Print "F_MoveToApproachPickCLip2: Start"
	WaitPos
	If AllowRotation Then
		Move P_AppPickCLip2 + P_FeederOffset ROT
	Else
		Move P_AppPickCLip2 + P_FeederOffset
	EndIf
	Out ReachedPos, APPROACH_PICKING_POS
	Print "F_MoveToApproachPickCLip2: Reached approach pick"
	
Fend

' ===== Function: F_MoveToPickClip1 =====
' Purpose: move to pick point (slow) applying feeder offset.
Function F_MoveToPickClip1
	
	Print "F_MoveToPickClip1: Start"
	Move P_PickClip1 + P_FeederOffset
	WaitPos
	Out ReachedPos, PICK_POS
	Print "F_MoveToPickClip1: Pick position reached"
	
Fend

' ===== Function: F_MoveToPickClip2 =====
' Purpose: move to pick point (slow) applying feeder offset.
Function F_MoveToPickClip2
	
	Print "F_MoveToPickClip2: Start"
	Move P_PickClip2 + P_FeederOffset
	WaitPos
	Out ReachedPos, PICK_POS
	Print "F_MoveToPickClip2: Pick position reached"
	
Fend

' ===== Function: F_MoveToApproach_LeftClip =====
' Purpose: go to approach left using conveyor offset.
Function F_MoveToApproach_LeftClip
	
	Print "F_MoveToApproach_LeftClip: Start"
	Move P_App_LeftClip + P_ConveyorOffset CP
	Out ReachedPos, APPROACH_INSERT_LH_POS
	Print "F_MoveToApproach_LeftClip: Reached approach left"
	
Fend

' ===== Function: F_MoveToApproach_RightClip =====
' Purpose: go to approach right using conveyor offset.
Function F_MoveToApproach_RightClip
	
	Print "F_MoveToApproach_RightClip: Start"
	Move P_App_RightClip + P_ConveyorOffset CP
	Out ReachedPos, APPROACH_INSERT_RH_POS
	Print "F_MoveToApproach_RightClip: Reached approach right"
	
Fend

' ===== Function: F_MoveToPlace_LeftClip =====
' Purpose: place left clip (slow) applying conveyor offset.
Function F_MoveToPlace_LeftClip
	
	Print "F_MoveToPlace_LeftClip: Start"
	Out ReachedPos, INSERT_LH_POS
	Move P_Place_LeftClip + P_ConveyorOffset
	WaitPos
	Print "F_MoveToPlace_LeftClip: Insert left reached"
	
Fend

' ===== Function: F_MoveToPlace_RightClip =====
' Purpose: place right clip (slow) applying conveyor offset.
Function F_MoveToPlace_RightClip
	
	Print "F_MoveToPlace_RightClip: Start"
	Out ReachedPos, INSERT_RH_POS
	Move P_Place_RightClip + P_ConveyorOffset
	WaitPos
	Print "F_MoveToPlace_RightClip: Insert right reached"
	
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
			
			Move (P_AppPickCLip1 + P_FeederOffset) :Z(SAFE_Z)
			
		Case APPROACH_PICKING_POS_2
			
			Move (P_AppPickCLip2 + P_FeederOffset) :Z(SAFE_Z)
			
		Case APPROACH_INSERT_LH_POS
		
			Move (P_App_LeftClip + P_ConveyorOffset) :Z(SAFE_Z)
			
		Case APPROACH_INSERT_RH_POS
			
			Move (P_App_RightClip + P_ConveyorOffset) :Z(SAFE_Z)
			
		Case PICK_POS
			
			Move (P_PickClip1 + P_FeederOffset) :Z(SAFE_Z)
		
		Case PICK_POS_2
			
			Move (P_PickClip2 + P_FeederOffset) :Z(SAFE_Z)
			
		Case INSERT_LH_POS
			
			Move (P_Place_LeftClip + P_ConveyorOffset) :Z(SAFE_Z)
			
		Case INSERT_RH_POS
			
			Move (P_Place_RightClip + P_ConveyorOffset) :Z(SAFE_Z)
		
		Default
			
			Quit All
		
	Send
Fend

' ===== Function: F_PickClipFromFeeder =====
' Purpose: approach feeder, wait sensor, pick and retreat.
Function F_PickClipFromFeeder
	
	
	
	If Oport(AtHomePos) Then
	'Do Nothing
	Else
		Print "F_PickClipFromFeeder: Start"
		Call F_SetAutoMotionHigh
		
		'If (Sw(ClipInFeeder) Or MemSw(M_ClipInFeeder)) And (Sw(ClipInverted) Or MemSw(M_ClipInverted)) Then
		'	WaitPos
		'	Call F_AllowRotationMotion
		'	Move P_AppPickCLip2 :Z(SAFE_Z) ROT
		'	Call F_SetAutoMotionHigh
		'	Call F_MoveToApproachPickCLip2(LINEAR_MOVEMENT)
		'Else
		Move P_AppPickCLip1 :Z(SAFE_Z)
		Call F_MoveToApproachPickCLip1
		'EndIf
			
		Print "F_PickClipFromFeeder: Waiting for ClipInFeeder"
	EndIf
	
	SAFE_WAIT((Sw(ClipInFeeder) Or MemSw(M_ClipInFeeder)))
	
	If Sw(ClipInverted) Or MemSw(M_ClipInverted) Then
		Call F_AllowRotationMotion
		Call F_MoveToApproachPickCLip2(TOOL_ROTATION) 'Rotate Tool
		Call F_SetAutoMotionLow
		Print "F_PickClipFromFeeder: Sensor active - moving to pick clip in pos 2"
		Call F_MoveToPickClip2
		Call F_CloseGrip
		Print "F_PickClipFromFeeder: Grip closed - retreating"
		Call F_SetAutoMotionHigh
		Call F_MoveToApproachPickCLip2(LINEAR_MOVEMENT)
		Move P_AppPickCLip2 :Z(SAFE_Z)
	Else
		Call F_SetAutoMotionLow
		Print "F_PickClipFromFeeder: Sensor active - moving to pick clip in pos 1"
		Call F_MoveToPickClip1
		Call F_CloseGrip
		Print "F_PickClipFromFeeder: Grip closed - retreating"
		Call F_SetAutoMotionHigh
		Call F_MoveToApproachPickCLip1
		Move P_AppPickCLip1 :Z(SAFE_Z)
	EndIf
	Print "F_PickClipFromFeeder: Done"
	
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

' ===== Function: F_PlaceLeftClip =====
' Purpose: move to left approach, wait body+conveyor, do insertion and retract.
Function F_PlaceLeftClip
	
	Print "F_PlaceLeftClip: Start"
	Print "F_PlaceLeftClip: Waiting BodyPresent AND ConveyorStopped"
	SAFE_WAIT(((Sw(BodyPresent) And Sw(ConveyorStopped)) Or (MemSw(M_BodyPresent) And MemSw(M_ConveyorStopped))))
	Print "F_PlaceLeftClip: Conditions OK - moving to place"
	Call F_SetAutoMotionLow
	Call F_MoveToPlace_LeftClip
	Call F_OpenGrip
	On WorkDone
	SAFE_WAIT((Sw(LhClipRequired) = 0))
	Off WorkDone
	Call F_SetAutoMotionHigh
	Call F_MoveToApproach_LeftClip
	Print "F_PlaceLeftClip: Set High Speed"
	Print "F_PlaceLeftClip: Going to Safe Position"
	'Move P_App_LeftClip :Z(SAFE_Z)
	Jump P_AppPickCLip1 LimZ (SAFE_Z)
	Print "F_PlaceLeftClip: Done"
	
Fend

' ===== Function: F_PlaceRightClip =====
' Purpose: move to right approach, wait body+conveyor, do insertion and retract.
Function F_PlaceRightClip
	
	Print "F_PlaceRightClip: Start"
	Print "F_PlaceRightClip: Waiting BodyPresent AND ConveyorStopped"
	SAFE_WAIT((Sw(BodyPresent) = 1 And Sw(ConveyorStopped)) Or (MemSw(M_BodyPresent) And MemSw(M_ConveyorStopped)))
	Print "F_PlaceRightClip: Conditions OK - moving to place"
	Call F_SetAutoMotionLow
	Call F_MoveToPlace_RightClip
	Call F_OpenGrip
	On WorkDone
	SAFE_WAIT((Sw(RhClipRequired) = 0))
	Off WorkDone
	Call F_SetAutoMotionHigh
	Call F_MoveToApproach_RightClip
	'Move P_App_RightClip :Z(SAFE_Z)
	Jump P_AppPickCLip1 LimZ (SAFE_Z)
	Print "F_PlaceRightClip: Done"
	
Fend

' ===== Function: F_CalculateOffset =====
' Purpose: compute offset between current TCP and the selected base point; send via OutReal.
'Note: Not tested yet
Function F_CalculateOffset
	
	Print "F_CalculateOffset: Start"
	
	' initialize temp'
	P_Adjustment = XY(0, 0, 0, 0)
	P_PositionToAdjust = XY(0, 0, 0, 0)
	P_Offset = XY(0, 0, 0, 0)
	
	Real Offset_X, Offset_Y, Offset_Z, Offset_U
	
	If Sw(HMI_Offset_sel) = FEEDER_OFFSET_SEL Then
		Print "F_CalculateOffset: Selected FEEDER group"
		P_PositionToAdjust = P_PickClip1 'Offset for feeder positions adjustment'
	Else
		Print "F_CalculateOffset: Selected CONVEYOR group"
		P_PositionToAdjust = P_Place_LeftClip 'Offset for conveyor positions adjustment'
	EndIf
	
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
'Note: Not tested yet
Function F_GetOffsetValues
	
	Print "F_GetOffsetValues: Start - reading offsets from PLC"
	Real ConveyorOffset_X, ConveyorOffset_Y, ConveyorOffset_Z, ConveyorOffset_U
	Real FeederOffset_X, FeederOffset_Y, FeederOffset_Z, FeederOffset_U
	
	'Get Both Offsets From Fieldbus Inputs'
	ConveyorOffset_X = InReal(PORT_FBIN_CONV_OFF_X)
	ConveyorOffset_Y = InReal(PORT_FBIN_CONV_OFF_Y)
	ConveyorOffset_Z = InReal(PORT_FBIN_CONV_OFF_Z)
	ConveyorOffset_U = InReal(PORT_FBIN_CONV_OFF_U)
	
	FeederOffset_X = InReal(PORT_FBIN_FEED_OFF_X)
	FeederOffset_Y = InReal(PORT_FBIN_FEED_OFF_Y)
	FeederOffset_Z = InReal(PORT_FBIN_FEED_OFF_Z)
	FeederOffset_U = InReal(PORT_FBIN_FEED_OFF_U)
	
	Print "F_GetOffsetValues: Read feeder offsets: X=" + Str$(FeederOffset_X) + " Y=" + Str$(FeederOffset_Y) + " Z=" + Str$(FeederOffset_Z) + " U=" + Str$(FeederOffset_U)
	Print "F_GetOffsetValues: Read conveyor offsets: X=" + Str$(ConveyorOffset_X) + " Y=" + Str$(ConveyorOffset_Y) + " Z=" + Str$(ConveyorOffset_Z) + " U=" + Str$(ConveyorOffset_U)
	
	P_ConveyorOffset = XY(ConveyorOffset_X, ConveyorOffset_Y, ConveyorOffset_Z, ConveyorOffset_U) 'Offset Adjustment for Related Conveyor Points'
	P_FeederOffset = XY(FeederOffset_X, FeederOffset_Y, FeederOffset_Z, FeederOffset_U) 'Offset Adjustment for Related Feeder Points'
	
	Print "F_GetOffsetValues: Updated local Point variables"
	
Fend

