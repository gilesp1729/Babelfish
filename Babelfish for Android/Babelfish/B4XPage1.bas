B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=8.5
@EndOfDesignText@
Sub Class_Globals
	Private Root As B4XView 'ignore
	Private xui As XUI 'ignore
	
	Private bgndColor As Int
	Private borderColor As Int
	Private textColor As Int

	Private pnlBackground As B4XView
	Private pnlSpeed As Panel
	Private pnlCadence As Panel
	Private pnlPower As Panel
	Private pnlBattery As Panel
	Private pnlPAS As Panel
	Private pnlRange As Panel
	Private pnlVolts As Panel
	Private pnlAmps As Panel
	Private pnlTrip As Panel
	Private pnlMax As Panel
	Private pnlAvg As Panel
	
	Private bc As ByteConverter
	Private UpdateTimer As Timer
	Private ConnectedDeviceType As Int
	Private lastWheelRev As Int
	Private lastWheelTime As Int
	Private lastCrankRev As Int
	Private lastCrankTime As Int
End Sub

'You can add more parameters here.
Public Sub Initialize As Object
	Log("Page Init")
	
	Return Me
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Log("Page Create")
	Root = Root1
	Root.LoadLayout("Page1")
	UpdateTimer.Initialize("UpdateTimer", 1000)
	
	bgndColor = Starter.bgndColor
	borderColor = Starter.borderColor
	textColor = Starter.textColor

End Sub

Private Sub B4XPage_Appear
	' Draw panels for quantities to be displayed
	pnlBackground.SetColorAndBorder(bgndColor, 0, borderColor, 0)
	
	' Go through the list of services and find out what we are connected to.
	' 0 = no relevant services (we just bail)
	' 1 = CSC service found
	' 2 = CP service found
	' 3 = CP service found as well as the custom motor service (0xFFF0)
	' There will generally be a Battery service along for the ride too.
	ConnectedDeviceType = 0
	Dim cscSeen = False As Boolean
	Dim cpSeen = False As Boolean
	Dim bfSeen = False As Boolean
	For Each s As String In Starter.ConnectedServices
		If s.ToLowerCase.StartsWith("00001816") Then	' CSC
			cscSeen = True
		Else If s.ToLowerCase.StartsWith("00001818") Then	' CP
			cpSeen = True
		Else If s.ToLowerCase.StartsWith("0000fff0") Then	' babelfish, but only if CP is also seen
			bfSeen = True
		End If
	Next
	If bfSeen And cpSeen Then
		ConnectedDeviceType = 3
	Else If cpSeen Then
		ConnectedDeviceType = 2
	Else If cscSeen Then
		ConnectedDeviceType = 1
	End If
	Log("Connected to device of type " & ConnectedDeviceType)
	
	' Set up display panels. If we have type 0 (nothing sensible is found)
	' then don't start the update timer, and warn the user it's a dead end.
	If ConnectedDeviceType == 3 Then
		' Set up for Babelfish Motor service and its characteristics
		' Some characteristics in the service change infrequently, so we read them
		' all on a timer rather than notifying
		UpdateTimer.Enabled = True
		' Draw the panels on the display			
		' Speed dial (TODO - numbers for now)
		DrawNumberPanel(pnlSpeed, "Speed", "km/h", False)

		' These sit on top of the speed dial, so transparent background
		DrawNumberPanel(pnlBattery, "", "", True)
		DrawNumberPanel(pnlPAS, "PAS", "", True)
		DrawNumberPanel(pnlRange, "Range", "km", True)
		DrawNumberPanel(pnlCadence, "Cad", "rpm", True)

		' The rest are lower down on  the page
		DrawNumberPanel(pnlTrip, "Trip", "km", False)
		DrawNumberPanel(pnlMax, "Max", "km/h", False)
		DrawNumberPanel(pnlAvg, "Avg", "km/h", False)

		DrawNumberPanel(pnlPower, "Power", "", False)
		DrawNumberPanel(pnlVolts, "Volts", "", False)
		DrawNumberPanel(pnlAmps, "Amps", "", False)

	Else if ConnectedDeviceType == 2 Then
		UpdateTimer.Enabled = True
		' Set up for CP service
		DrawNumberPanel(pnlSpeed, "Speed", "km/h", False)
		DrawNumberPanel(pnlBattery, "", "", True)
		DrawNumberPanel(pnlCadence, "Cad", "rpm", True)
		DrawNumberPanel(pnlRange, "Power", "", True)		' Use Range field for power to keep it neat.
		DrawNumberPanelBlank(pnlTrip)
		DrawNumberPanelBlank(pnlMax)
		DrawNumberPanelBlank(pnlAvg)
		DrawNumberPanelBlank(pnlPower)
		DrawNumberPanelBlank(pnlVolts)
		DrawNumberPanelBlank(pnlAmps)
		DrawNumberPanelBlank(pnlPAS)

	Else If ConnectedDeviceType == 1 Then
		UpdateTimer.Enabled = True
		' Set up for CSC service. Note that cadence may not be present.
		' This depends on some bits in a characteristic that comes with it,
		' but we just put up the panel anyway.
		DrawNumberPanel(pnlSpeed, "Speed", "km/h", False)
		DrawNumberPanel(pnlBattery, "", "", True)
		DrawNumberPanel(pnlCadence, "Cad", "rpm", True)
		DrawNumberPanelBlank(pnlTrip)
		DrawNumberPanelBlank(pnlMax)
		DrawNumberPanelBlank(pnlAvg)
		DrawNumberPanelBlank(pnlPower)
		DrawNumberPanelBlank(pnlVolts)
		DrawNumberPanelBlank(pnlAmps)
		DrawNumberPanelBlank(pnlPAS)
		DrawNumberPanelBlank(pnlRange)

	Else
		ToastMessageShow("No usable services found.", False)				
	End If
End Sub

Private Sub B4XPage_Disappear
	UpdateTimer.Enabled = False
End Sub

' When timer fires, read all the characteristics for all te services.
Sub UpdateTimer_Tick
	For Each s As String In Starter.ConnectedServices
		Starter.manager.ReadData(s)
	Next
End Sub

' Unsigned byte helpers
Sub Unsigned(b As Byte) As Int
	Return Bit.And(0xFF, b)
End Sub

Sub Unsigned2(b0 As Byte, b1 As Byte) As Int
	Return Bit.Or(Bit.ShiftLeft(Unsigned(b1), 8), Unsigned(b0))
End Sub

Sub Unsigned4(b0 As Byte, b1 As Byte, b2 As Byte, b3 As Byte) As Int
	Dim result As Int = Unsigned(b0)
	result = Bit.Or(result, Bit.ShiftLeft(Unsigned(b1), 8))
	result = Bit.Or(result, Bit.ShiftLeft(Unsigned(b2), 16))
	result = Bit.Or(result, Bit.ShiftLeft(Unsigned(b3), 24))
	Return result
End Sub


' Callback for DataAvailable event (caught in main page?!).
' This handles all characteristics for all possible services.
Sub AvailCallback(ServiceId As String, Characteristics As Map)
	Dim b(20) As Byte
	Dim battIcon As String
	
	Log("Service " & ServiceId)
	For Each id As String In Characteristics.Keys
		Log("Char ID " & id)
		b = Characteristics.Get(id)
		Log(bc.HexFromBytes(b))
		
		If ConnectedDeviceType == 3 Then
			' Babelfish Motor service
			If id.ToLowerCase.StartsWith("0000fff1") Then
				' Motor measurement
				DrawNumberPanelValue(pnlSpeed, Unsigned2(b(0), b(1)), 100, 1, "")
				DrawNumberPanelValue(pnlCadence, Unsigned(b(2)), 1, 0, "")
				DrawNumberPanelValue(pnlPAS, Unsigned(b(11)), 1, 0, "")		' TODO make this a string
				DrawNumberPanelValue(pnlRange, Unsigned2(b(9), b(10)), 100, 0, "")

				DrawNumberPanelValue(pnlPower, Unsigned2(b(3), b(4)), 1, 0, "W")
				DrawNumberPanelValue(pnlVolts, Unsigned2(b(5), b(6)), 100, 1, "V")
				DrawNumberPanelValue(pnlAmps, Unsigned2(b(7), b(8)), 100, 1, "A")
				
			else If id.ToLowerCase.StartsWith("0000fff2") Then
				' Motor settings
				' TODO Leave this out for now


			else If id.ToLowerCase.StartsWith("0000fff3") Then
				' Motor resettable trip
				DrawNumberPanelValue(pnlTrip, Unsigned2(b(2), b(3)), 10, 1, "")
				DrawNumberPanelValue(pnlMax, Unsigned2(b(6), b(7)), 10, 0, "")
				DrawNumberPanelValue(pnlAvg, Unsigned2(b(4), b(5)), 10, 1, "")
					
			End If
		
		Else If ConnectedDeviceType == 2 Then
			' CP service. This is processed like the CSC except that for some god-only-knows
			' reason, the wheel time is in HALF-millseconds. 
			If id.ToLowerCase.StartsWith("00002a63") Then
				' CP measurement
				' Flags bits tell which fields are present. We assume the speed (wheel pair)
				' is always present, since we can't handle separate devices for speed and cadence.
				Dim flags As Int = Unsigned2(b(0), b(1))
				' Power is bytes 2/3. Use the Range field to keep things neatly within the speed dial.
				DrawNumberPanelValue(pnlRange, Unsigned2(b(2), b(3)), 1, 0, "W")

				' Wheel revolutions and wheel time
				Dim wheelRev As Int = Unsigned4(b(4), b(5), b(6), b(7))
				Dim wheelTime As Int = Unsigned2(b(8), b(9)) / 2	' Half-ms, don't forget
				Dim circ As Int = 2312			' hard code this circumference for now
				
				If (wheelTime - lastWheelTime > 0) Then
					' The division yields mm/ms (=m/s). Convert it to km/h*10
					Dim Speedx10 As Int = ((wheelRev - lastWheelRev) * circ * 36) / (wheelTime - lastWheelTime)
					DrawNumberPanelValue(pnlSpeed, Speedx10, 10, 1, "")
					lastWheelRev = wheelRev
					lastWheelTime = wheelTime
				End If

				If Bit.And(flags, 0x20) <> 0 Then	' the cadence fields are present
					Dim crankRev As Int = Unsigned2(b(10), b(11))
					Dim crankTime As Int = Unsigned2(b(12), b(13))
					If (crankTime - lastCrankTime > 0) Then
						' Cadence in rpm
						Dim cad As Int = ((crankRev - lastCrankRev) * 60000) / (crankTime - lastCrankTime)
						DrawNumberPanelValue(pnlCadence, cad, 1, 0, "")
						lastCrankRev = crankRev
						lastCrankTime = crankTime
					End If
				End If
			End If
			
		Else If ConnectedDeviceType == 1 Then
			' CSC service.
			If id.ToLowerCase.StartsWith("00002a5b") Then
				' Flags bits tell which fields are present. We assume the speed (wheel pair)
				' is always present, since we can't handle separate devices for speed and cadence.
				Dim flags As Int = Unsigned(b(0))

				' Wheel revolutions and wheel time
				Dim wheelRev As Int = Unsigned4(b(1), b(2), b(3), b(4))
				Dim wheelTime As Int = Unsigned2(b(5), b(6))
				Dim circ As Int = 2312			' hard code this circumference for now
				
				If (wheelTime - lastWheelTime > 0) Then
					' The division yields mm/ms (=m/s). Convert it to km/h*10
					Dim Speedx10 As Int = ((wheelRev - lastWheelRev) * circ * 36) / (wheelTime - lastWheelTime)
					DrawNumberPanelValue(pnlSpeed, Speedx10, 10, 1, "")
					lastWheelRev = wheelRev
					lastWheelTime = wheelTime
				End If

				If Bit.And(flags, 0x2) <> 0 Then	' the cadence fields are present
					Dim crankRev As Int = Unsigned2(b(7), b(8))
					Dim crankTime As Int = Unsigned2(b(9), b(10))
					If (crankTime - lastCrankTime > 0) Then
						' Cadence in rpm
						Dim cad As Int = ((crankRev - lastCrankRev) * 60000) / (crankTime - lastCrankTime)
						DrawNumberPanelValue(pnlCadence, cad, 1, 0, "")
						lastCrankRev = crankRev
						lastCrankTime = crankTime
					End If
				End If
				
			End If
			
		End If

		' In any event, diplay the battery level from the battery service.
		If id.ToLowerCase.StartsWith("00002a19") Then
			' battery level characteristic. These characters are
			' Awesome icons representing battery state of charge.
			DrawNumberPanelValue(pnlBattery, Unsigned(b(0)), 1, 0, "% ")  ' note trailing space
			If b(0) > 80 Then
				battIcon = ""
			Else If b(0) > 60 Then
				battIcon = ""
			Else If b(0) > 40 Then
				battIcon = ""
			Else If b(0) > 20 Then
				battIcon = ""
			Else
				battIcon = ""
			End If
			DrawStringPanelValue(pnlBattery, battIcon)
					
		End If
	Next
End Sub


' Draw a number panel. There are three standard labels in the panel:
' 0 = Name
' 1 = unit
' 2 = Value
' As drawn, the value is set to "--". 
' If transparent, background is transparent and border width is zero.
Sub DrawNumberPanel(pan As B4XView, Name As String, Unit As String, transparent As Boolean)
	Dim N As B4XView = pan.GetView(0)
	Dim U As B4XView = pan.GetView(1)
	Dim V As B4XView = pan.GetView(2)
	If transparent Then
		pan.SetColorAndBorder(Bit.And(bgndColor, 0x00FFFFFF), 0, borderColor, 0)
	Else
		pan.SetColorAndBorder(bgndColor, 2dip, borderColor, 0)
	End If
	N.TextColor = textColor
	U.TextColor = textColor
	V.TextColor = textColor
	N.Text = Name
	U.Text = Unit
	V.Text = "--"
End Sub

' Draw the value in a number panel. Optionally append a unit when it would 
' look better that way (like a battery percentage)
Sub DrawNumberPanelValue(pan As B4XView, Value As Int, Div As Int, Decpl As Int, Append As String)
	Dim V As B4XView = pan.GetView(2)
	Dim fval As Float = Value / Div
	' Divide by the division factor (e.g. 10 or 100) before displaying.
	' Format the fval with Decpl places. Append any optional string.
	V.Text = NumberFormat(fval, 1, Decpl) & Append
	' TODO Optional dec pl for small numbers (like speed)
End Sub

' Draw a string in the panel value. This can be an Awesome icon or a string
' representing, say, a PAS level.
Sub DrawStringPanelValue(pan As B4XView, str As String)
	Dim V As B4XView = pan.GetView(3)   ' the string carrying the icon
	V.TextColor = textColor		' it hasn't been set by DrawNumberPanel
	V.Text = str	
End Sub

' Fill a number panel with a blank background.
Sub DrawNumberPanelBlank(pan as B4XView)
	pan.SetColorAndBorder(Bit.And(bgndColor, 0x00FFFFFF), 0, borderColor, 0)
End Sub
