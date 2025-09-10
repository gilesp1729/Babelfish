B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=8.5
@EndOfDesignText@
Sub Class_Globals
	Private Root As B4XView 'ignore
	Private xui As XUI 'ignore
	Private MainPage As B4XMainPage
	Private Page2 As B4XPage2
	
	Private bgndColor As Int
	Private borderColor As Int
	Private textColor As Int
	
	' Panels on the display
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
	Private pnlLimit As Panel
	Private pnlWheelSize As Panel
	Private pnlCirc As Panel
	Private pnlNewLimit As Panel
	Private pnlNewWheelSize As Panel
	Private pnlNewCirc As Panel
	Private pnlOdo As Panel
	Private pnlClock As Panel
	
	Private bc As ByteConverter
	Private cscService, cpService, bfService, batService As String
	Private servList As List
	
	' For CSC and CP
	Private UpdateTimer As Timer
	Private ConnectedDeviceType As Int
	Private lastWheelRev As Int = 0
	Private lastWheelTime As Int
	Private lastCrankRev As Int = 0
	Private lastCrankTime As Int
	
	' For the speed dial display
	Private Const Pi As Float = 3.14159
	Private Const gap As Float = 20dip
	Private Const stp As Float = 0.05
	Private MaxSpdx10 As Int = 0
	Private AvgSpdx10 As Int = 0
	Private cvsSpeed As B4XCanvas
	
	' For the speed limit display and interaction on the speed dial
	Private SpeedLimitx100 As Int
	Private WheelCirc As Int
	Private WheelSize124 As Int
	Private settingsService As String
	Private settingsChar As String

	Private NewSpeedLimitx100 As Int
	Private NewWheelCirc As Int
	Private NewWheelSize124 As Int
	Private SettingsValid As Boolean = False
	Private NewSettingsValid As Boolean = False
	
	' For catching long presses and triggering Page 2
	Private DownX, DownY As Float
	Private longPressed As Boolean
	Private LongPressTimer As Timer
	
	' For accumulating the average and max speeds and trip counter
	Private nSamples As Int
	Private Trip As Float
	Private prevLocation As Location
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
	UpdateTimer.Initialize("UpdateTimer", 500)
	LongPressTimer.Initialize("LongPressTimer", 1500)
	
	bgndColor = Starter.bgndColor
	borderColor = Starter.borderColor
	textColor = Starter.textColor
	
	cvsSpeed.Initialize(pnlSpeed)

End Sub

'--------------------------------------------------------------------------
' Handle initial drawing of the page.

Private Sub B4XPage_Appear
	' Draw panels for quantities to be displayed

	' Set background panel to the background color
	pnlBackground.SetColorAndBorder(bgndColor, 0, borderColor, 0)

	' Start GPS. Updates no more than every 500ms, and after 1 metre of movement.
	MainPage = B4XPages.GetPage("MainPage")
	MainPage.Gnss1.Start(500, 1.0)
	ZeroTripMaxAvg

	' Set action bar to show the save button. Change it to "map"
	B4XPages.GetManager.ActionBar.RunMethod("setDisplayOptions", Array(16, 16))
	MainPage.btnSave.Text = "Map"	
	
	' Go through the list of services and find out what we are connected to.
	' 0 = no relevant services (we just bail)
	' 1 = CSC service found
	' 2 = CP service found
	' 3 = CP service found as well as the custom motor service (0xFFF0)
	' There will generally be a Battery service along for the ride too.
	' Collect their UUIDs here.
	ConnectedDeviceType = 0
	Dim cscSeen = False As Boolean
	Dim cpSeen = False As Boolean
	Dim bfSeen = False As Boolean
	Dim batSeen = False As Boolean
	servList.Initialize
	For Each s As String In Starter.ConnectedServices
		If s.ToLowerCase.StartsWith("00001816") Then	' CSC
			cscSeen = True
			cscService = s
		Else If s.ToLowerCase.StartsWith("00001818") Then	' CP
			cpSeen = True
			cpService = s
		Else If s.ToLowerCase.StartsWith("0000fff0") Then	' Babelfish, but only if CP is also seen
			bfSeen = True	' Comment this out to simulate CP from Babelfish
			bfService = s
		Else if	s.ToLowerCase.StartsWith("0000180f") Then	' Battery service
			batSeen = True
			batService = s
		End If
	Next
	If bfSeen And cpSeen Then
		ConnectedDeviceType = 3
		servList.Add(bfService)
	Else If cpSeen Then
		ConnectedDeviceType = 2
		servList.Add(cpService)
	Else If cscSeen Then
		ConnectedDeviceType = 1
		servList.Add(cscService)
	End If
	If batSeen Then
		servList.Add(batService)
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
		ClearSpeedDial(pnlSpeed, cvsSpeed, "Speed", "km/h")
		DrawSpeedDial(pnlSpeed, cvsSpeed)
				
		' These sit on top of the speed dial panel, so transparent background
		DrawNumberPanel(pnlBattery, "", "", True)
		DrawNumberPanel(pnlPAS, "PAS", "", True)
		DrawNumberPanel(pnlRange, "Range", "km", True)
		DrawNumberPanel(pnlCadence, "", "rpm", True)	' Don't show "cad" as it gets in the way of the speed dial
		DrawNumberPanel(pnlClock, "Time", "", True)

		' The rest are lower down on  the page
		DrawNumberPanel(pnlTrip, "Trip", "km", False)
		DrawNumberPanel(pnlMax, "Max", "km/h", False)
		DrawNumberPanel(pnlAvg, "Avg", "km/h", False)

		DrawNumberPanel(pnlPower, "Power", "", False)
		DrawNumberPanel(pnlVolts, "Volts", "", False)
		DrawNumberPanel(pnlAmps, "Amps", "", False)

		DrawNumberPanel(pnlLimit, "Limit", "km/h", False)
		DrawNumberPanel(pnlWheelSize, "Wheel", "in", False)
		DrawNumberPanel(pnlCirc, "Circ", "mm", False)

		DrawNumberPanel(pnlNewLimit, "NewLm", "km/h", False)
		DrawNumberPanel(pnlNewWheelSize, "NewSz", "in", False)
		DrawNumberPanel(pnlNewCirc, "NewCr", "mm", False)
		
		DrawNumberPanel(pnlOdo, "Odo", "km", False)

	Else if ConnectedDeviceType == 2 Then
		UpdateTimer.Enabled = True

		' Set up for CP service
		ClearSpeedDial(pnlSpeed, cvsSpeed, "Speed", "km/h")
		DrawSpeedDial(pnlSpeed, cvsSpeed)

		DrawNumberPanel(pnlBattery, "", "", True)
		DrawNumberPanel(pnlCadence, "", "rpm", True)	' Don't show "cad" as it gets in the way of the speed dial
		DrawNumberPanel(pnlPAS, "Power", "", True)		' Use PAS field for power to keep it neat.
		DrawNumberPanel(pnlClock, "Time", "", True)
		DrawNumberPanel(pnlTrip, "Trip", "km", False)	' These are calculated values
		DrawNumberPanel(pnlMax, "Max", "km/h", False)
		DrawNumberPanel(pnlAvg, "Avg", "km/h", False)
		DrawNumberPanelBlank(pnlPower)
		DrawNumberPanelBlank(pnlVolts)
		DrawNumberPanelBlank(pnlAmps)
		DrawNumberPanelBlank(pnlRange)
		DrawNumberPanelBlank(pnlLimit)
		DrawNumberPanelBlank(pnlWheelSize)
		DrawNumberPanelBlank(pnlCirc)
		DrawNumberPanelBlank(pnlNewLimit)
		DrawNumberPanelBlank(pnlNewWheelSize)
		DrawNumberPanelBlank(pnlNewCirc)
		DrawNumberPanelBlank(pnlOdo)

	Else If ConnectedDeviceType == 1 Then
		UpdateTimer.Enabled = True

		' Set up for CSC service. Note that cadence may not be present.
		' This depends on some bits in a characteristic that comes with it,
		' but we just put up the panel anyway.
		ClearSpeedDial(pnlSpeed, cvsSpeed, "Speed", "km/h")
		DrawSpeedDial(pnlSpeed, cvsSpeed)

		DrawNumberPanel(pnlBattery, "", "", True)
		DrawNumberPanel(pnlCadence, "", "rpm", True)	' Don't show "cad" as it gets in the way of the speed dial
		DrawNumberPanel(pnlClock, "Time", "", True)
		DrawNumberPanel(pnlTrip, "Trip", "km", False)
		DrawNumberPanel(pnlMax, "Max", "km/h", False)
		DrawNumberPanel(pnlAvg, "Avg", "km/h", False)
		DrawNumberPanelBlank(pnlPower)
		DrawNumberPanelBlank(pnlVolts)
		DrawNumberPanelBlank(pnlAmps)
		DrawNumberPanelBlank(pnlPAS)
		DrawNumberPanelBlank(pnlRange)
		DrawNumberPanelBlank(pnlLimit)
		DrawNumberPanelBlank(pnlWheelSize)
		DrawNumberPanelBlank(pnlCirc)
		DrawNumberPanelBlank(pnlNewLimit)
		DrawNumberPanelBlank(pnlNewWheelSize)
		DrawNumberPanelBlank(pnlNewCirc)
		DrawNumberPanelBlank(pnlOdo)

	Else
		ToastMessageShow("No usable services found. Defaulting to GPS", False)
		
		' Don't start the update timer, but start the GPS service to obtain speed readings.
		ClearSpeedDial(pnlSpeed, cvsSpeed, "Speed", "km/h")
		DrawSpeedDial(pnlSpeed, cvsSpeed)

		DrawNumberPanelBlank(pnlBattery)
		DrawNumberPanelBlank(pnlCadence)
		DrawNumberPanel(pnlClock, "Time", "", True)
		DrawNumberPanel(pnlTrip, "Trip", "km", False)
		DrawNumberPanel(pnlMax, "Max", "km/h", False)
		DrawNumberPanel(pnlAvg, "Avg", "km/h", False)
		DrawNumberPanelBlank(pnlPower)
		DrawNumberPanelBlank(pnlVolts)
		DrawNumberPanelBlank(pnlAmps)
		DrawNumberPanelBlank(pnlPAS)
		DrawNumberPanelBlank(pnlRange)
		DrawNumberPanelBlank(pnlLimit)
		DrawNumberPanelBlank(pnlWheelSize)
		DrawNumberPanelBlank(pnlCirc)
		DrawNumberPanelBlank(pnlNewLimit)
		DrawNumberPanelBlank(pnlNewWheelSize)
		DrawNumberPanelBlank(pnlNewCirc)
		DrawNumberPanelBlank(pnlOdo)
	End If
End Sub

Private Sub B4XPage_Disappear
	UpdateTimer.Enabled = False
	MainPage.Gnss1.Stop
End Sub

'--------------------------------------------------------------------------
' Handle repeated reading of GPS fix when using the GPS Bike (no Bluetooth)

' This is called whenever the location changes.

' We don't want all of this when using CP/CSC or just updating 
' a Google Maps position with BF.

Sub Gnss1_LocationChanged (Location1 As Location)

	If ConnectedDeviceType == 0 Then
		If Not(Location1.SpeedValid) Then
			Return
		End If
		Dim Speedx100 As Int = Location1.Speed * 360
		DrawNumberPanelValue(pnlSpeed, Speedx100, 100, 1, "")
		
		' Update trip counter, max and average speeds.
		Dim Dist As Float = 0
		If nSamples > 0 Then
			Dist = Location1.DistanceTo(prevLocation) / 1000
		End If
		
		UpdateTripMaxAvg(Dist, Location1.Speed * 3.6)
		prevLocation = Location1

		' While here, update the clock.
		DrawStringPanelValue(pnlClock, DateTime.Time(DateTime.Now))
	End If
End Sub

#if 0
' Show all the satellites in view.
Sub Gnss1_GnssStatus  (SatelliteInfo As GnssStatus)
	Dim sb As StringBuilder
	sb.Initialize
	sb.Append("Satellites:").Append(CRLF)
	For i = 0 To SatelliteInfo.SatelliteCount - 1
		sb.Append(CRLF).Append(SatelliteInfo.Svid(i)).Append($" $1.2{SatelliteInfo.Cn0DbHz(i)}"$).Append(" ").Append(SatelliteInfo.UsedInFix(i))
		sb.Append($" $1.2{SatelliteInfo.Azimuth(i)}"$).Append($" $1.2{SatelliteInfo.Elevation(i)}"$)
		sb.Append($" $1.2{SatelliteInfo.CarrierFrequencyHz(i) / 1000000} MHz"$)
		sb.Append(" ").Append(MainPage.ConstellationToString.GetDefault(SatelliteInfo.ConstellationType(i), "unknown"))
	Next
	Log(sb.ToString)
End Sub
#end if

'--------------------------------------------------------------------------
' Update the trip, max and average speeds, for devices that do not supply these values directly.
Sub UpdateTripMaxAvg(dist As Float, speed As Float)
	Dim spdx10 As Int = speed * 10
	
	Trip = Trip + dist
	If spdx10 > MaxSpdx10 Then
		MaxSpdx10 = spdx10
	End If
	AvgSpdx10 = ((AvgSpdx10 * nSamples) + spdx10) / (nSamples + 1)
	nSamples = nSamples + 1

	DrawNumberPanelValue(pnlTrip, (Trip * 10).As(Int), 10, 1, "")
	DrawNumberPanelValue(pnlMax, MaxSpdx10, 10, 0, "")
	DrawNumberPanelValue(pnlAvg, AvgSpdx10, 10, 1, "")
End Sub

' Zero the trip, max and average fields.
Sub ZeroTripMaxAvg
	nSamples = 0
	AvgSpdx10 = 0
	MaxSpdx10 = 0
	Trip = 0
	prevLocation.Initialize
End Sub

'--------------------------------------------------------------------------
' Handle repeated reading of characteristics from the connected peripheral

' When timer fires, read all the characteristics for all the wanted services.
Sub UpdateTimer_Tick
	For Each s As String In servList
		'Log("ReadData from " & s)
		Starter.manager.ReadData(s)
	Next
	' While here, update the clock.
	DrawStringPanelValue(pnlClock, DateTime.Time(DateTime.Now))
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
	Dim PASLevels() As String
	PASLevels = Array As String ("Off", "Eco", "Tour", "Sport", "Sp+", "Boost")
	'Log("------------------- AVAIL CALLBACK -----------------------")
	'Log("Service " & ServiceId)
	For Each id As String In Characteristics.Keys
		'Log("Char ID " & id)
		'Log("Props " & Starter.manager.GetCharacteristicProperties(ServiceId, id))
		b = Characteristics.Get(id)
		'Log(bc.HexFromBytes(b))
		
		If ConnectedDeviceType == 3 Then
			' Babelfish Motor service
			If id.ToLowerCase.StartsWith("0000fff1") Then
				' Motor measurement
				Dim Speedx100 As Int = Unsigned2(b(0), b(1))
				ClearSpeedDial(pnlSpeed, cvsSpeed, "Speed", "km/h")
				DrawSpeedDial(pnlSpeed, cvsSpeed)
				DrawNumberPanelValue(pnlSpeed, Speedx100, 100, 1, "")
				DrawSpeedStripe(pnlSpeed, cvsSpeed, Speedx100 / 10)
				' Draw things that have to appear on top of the speed stripe
				DrawSpeedMark(pnlSpeed, cvsSpeed, MaxSpdx10, Colors.Red)
				DrawSpeedMark(pnlSpeed, cvsSpeed, AvgSpdx10, Colors.Yellow)
				' Draw speed limit spot when a speed limit packet has been
				' received on the CAN bus. They are infrequent (15-20 seconds apart)
				DrawSpeedLimitSpot(pnlSpeed, cvsSpeed)
				
				DrawNumberPanelValue(pnlCadence, Unsigned(b(2)), 1, 0, "")
				DrawNumberPanelValue(pnlRange, Unsigned2(b(9), b(10)), 100, 0, "")

				DrawNumberPanelValue(pnlPower, Unsigned2(b(3), b(4)), 1, 0, "W")
				DrawNumberPanelValue(pnlVolts, Unsigned2(b(5), b(6)), 100, 1, "V")
				DrawNumberPanelValue(pnlAmps, Unsigned2(b(7), b(8)), 100, 1, "A")
				
				DrawStringPanelValue(pnlPAS, PASLevels(Unsigned(b(11))))
				
			else If id.ToLowerCase.StartsWith("0000fff2") Then
				' Motor settings. Only display these (both read and written) if they have valid data.
				If (b(6) <> 0) Then  ' valid read from peripheral
					SettingsValid = True
					SpeedLimitx100 = Unsigned2(b(0), b(1))
					DrawNumberPanelValue(pnlLimit, SpeedLimitx100, 100, 0, "")
					WheelCirc = Unsigned2(b(2), b(3))
					DrawNumberPanelValue(pnlCirc, WheelCirc, 1, 0, "")
					' Unscramble the 12.4 encoding of wheel size
					WheelSize124 = Unsigned2(b(4), b(5))
					Dim wheelx10 As Int = Bit.ShiftRight(WheelSize124, 4) * 10 + Bit.And(WheelSize124, 0xF)
					DrawNumberPanelValue(pnlWheelSize, wheelx10, 10, 1, "")
				End If
									
				If NewSettingsValid Then
					DrawNumberPanelValue(pnlNewLimit, NewSpeedLimitx100, 100, 0, "")
					DrawNumberPanelValue(pnlNewCirc, NewWheelCirc, 1, 0, "")
					wheelx10 = Bit.ShiftRight(NewWheelSize124, 4) * 10 + Bit.And(NewWheelSize124, 0xF)
					DrawNumberPanelValue(pnlNewWheelSize, wheelx10, 10, 1, "")
				End If

			else If id.ToLowerCase.StartsWith("0000fff3") Then
				' Writable new settings. Remember the service and char ID's for later writing
				settingsService = ServiceId
				settingsChar = id

			else If id.ToLowerCase.StartsWith("0000fff4") Then
				' Motor resettable trip
				DrawNumberPanelValue(pnlTrip, Unsigned2(b(2), b(3)), 10, 1, "")
				DrawNumberPanelValue(pnlOdo, Unsigned2(b(0), b(1)), 1, 1, "")
				' Store these for the next speed dial update. They don't change frequently
				MaxSpdx10 = Unsigned2(b(6), b(7))
				DrawNumberPanelValue(pnlMax, MaxSpdx10, 10, 0, "")
				AvgSpdx10 = Unsigned2(b(4), b(5))
				DrawNumberPanelValue(pnlAvg, AvgSpdx10, 10, 1, "")
					
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
				DrawNumberPanelValue(pnlPAS, Unsigned2(b(2), b(3)), 1, 0, "W")

				' Wheel revolutions and wheel time
				Dim wheelRev As Int = Unsigned4(b(4), b(5), b(6), b(7))
				Dim wheelTime As Int = Unsigned2(b(8), b(9)) / 2	' Half-ms, don't forget
				Dim circ As Int = 2312			' TODO hard code this circumference for now
				If lastWheelRev == 0 Then
					lastWheelRev = wheelRev				
				End If
				If (wheelTime - lastWheelTime > 0) Then
					' The division yields mm/ms (=m/s). Convert it to km/h*10
					Dim Speedx10 As Int = ((wheelRev - lastWheelRev) * circ * 36) / (wheelTime - lastWheelTime)
					ClearSpeedDial(pnlSpeed, cvsSpeed, "Speed", "km/h")
					DrawSpeedDial(pnlSpeed, cvsSpeed)
					DrawNumberPanelValue(pnlSpeed, Speedx10, 10, 1, "")
					DrawSpeedStripe(pnlSpeed, cvsSpeed, Speedx10)
					'Log("Speedx10 " & Speedx10)
					'Log("wheelRev " & wheelRev & " last wheelrev " & lastWheelRev)
					UpdateTripMaxAvg(((wheelRev - lastWheelRev) * circ).As(Float) / 1000000, Speedx10.As(Float) / 10)
					DrawSpeedMark(pnlSpeed, cvsSpeed, MaxSpdx10, Colors.Red)
					DrawSpeedMark(pnlSpeed, cvsSpeed, AvgSpdx10, Colors.Yellow)
				End If
				lastWheelRev = wheelRev		
				lastWheelTime = wheelTime

				If Bit.And(flags, 0x20) <> 0 Then	' the cadence fields are present
					Dim crankRev As Int = Unsigned2(b(10), b(11))
					Dim crankTime As Int = Unsigned2(b(12), b(13))
					If lastCrankRev == 0 Then
						lastCrankRev = crankRev
					End If
					If (crankTime - lastCrankTime > 0) Then
						' Cadence in rpm
						Dim cad As Int = ((crankRev - lastCrankRev) * 60000) / (crankTime - lastCrankTime)
						DrawNumberPanelValue(pnlCadence, cad, 1, 0, "")
					End If
					lastCrankRev = crankRev
					lastCrankTime = crankTime
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
				If lastWheelRev == 0 Then
					lastWheelRev = wheelRev
				End If
				
				If (wheelTime - lastWheelTime > 0) Then
					' The division yields mm/ms (=m/s). Convert it to km/h*10
					Dim Speedx10 As Int = ((wheelRev - lastWheelRev) * circ * 36) / (wheelTime - lastWheelTime)
					ClearSpeedDial(pnlSpeed, cvsSpeed, "Speed", "km/h")
					DrawSpeedDial(pnlSpeed, cvsSpeed)
					DrawNumberPanelValue(pnlSpeed, Speedx10, 10, 1, "")
					DrawSpeedStripe(pnlSpeed, cvsSpeed, Speedx10)
					UpdateTripMaxAvg(((wheelRev - lastWheelRev) * circ).As(Float) / 1000000, Speedx10.As(Float) / 10)
					DrawSpeedMark(pnlSpeed, cvsSpeed, MaxSpdx10, Colors.Red)
					DrawSpeedMark(pnlSpeed, cvsSpeed, AvgSpdx10, Colors.Yellow)
				End If
				lastWheelRev = wheelRev
				lastWheelTime = wheelTime

				If Bit.And(flags, 0x2) <> 0 Then	' the cadence fields are present
					Dim crankRev As Int = Unsigned2(b(7), b(8))
					Dim crankTime As Int = Unsigned2(b(9), b(10))
					If lastCrankRev == 0 Then
						lastCrankRev = crankRev
					End If
					If (crankTime - lastCrankTime > 0) Then
						' Cadence in rpm
						Dim cad As Int = ((crankRev - lastCrankRev) * 60000) / (crankTime - lastCrankTime)
						DrawNumberPanelValue(pnlCadence, cad, 1, 0, "")
					End If
					lastCrankRev = crankRev
					lastCrankTime = crankTime
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
			DrawStringPanelIcon(pnlBattery, battIcon)
					
		End If
	Next
End Sub

'--------------------------------------------------------------------------
' Drawing routines

' Draw a number panel. There are three standard labels in the panel:
' 0 = Name
' 1 = unit
' 2 = Value
' As drawn, the value is set to "--". 
' If transparent, background is transparent and border width is zero.
' DO NOT use with graphics like the speed dial (the SetColorAndBorder will clobber them)
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
	V.Text = NumberFormat2(fval, 1, Decpl, 0, False) & Append
	' TODO Optional dec pl for small numbers (like speed 8.5, 9.5, but 10, 20...)
	' It would have to be for speed only. Not volts, amps, or wheel size.
End Sub

' Draw a string in the extra field. This can be an Awesome icon.
Sub DrawStringPanelIcon(pan As B4XView, str As String)
	Dim V As B4XView = pan.GetView(3)   ' the string carrying the icon
	V.TextColor = textColor		' it hasn't been set by DrawNumberPanel
	V.Text = str
End Sub

' Draw a string in the panel's value field.
Sub DrawStringPanelValue(pan As B4XView, str As String)
	Dim V As B4XView = pan.GetView(2)   ' the string carrying the icon
	V.TextColor = textColor		' it hasn't been set by DrawNumberPanel
	V.Text = str	
End Sub

' Fill a number panel with a blank background.
Sub DrawNumberPanelBlank(pan As B4XView)
	pan.SetColorAndBorder(Bit.And(bgndColor, 0x00FFFFFF), 0, borderColor, 0)
End Sub

' Draw a speed dial for the speed panel. Separate routines to clear
' the background of the panel and set the speed stripe and other
' bits and pieces.

Sub ClearSpeedDial(pan As Panel, cvs As B4XCanvas, Name As String, Unit As String)
	
	Dim rect As B4XRect
	
	rect.Initialize(0, 0, pan.Width, pan.Height)
	cvs.ClearRect(rect)
	
	Dim N As B4XView = pan.GetView(0)
	Dim U As B4XView = pan.GetView(1)
	Dim V As B4XView = pan.GetView(2)
	N.TextColor = textColor
	U.TextColor = textColor
	V.TextColor = textColor
	N.Text = Name
	U.Text = Unit
	V.Text = "--"

End Sub

' Generate a path for the speed dial outline (to be stroked for the
' framework, or filled for the speed stripe).
' The angles are in the mathematical sense (anticlockwise from east)
Sub SpeedDialPath(pan As Panel, startAngle As Float, finishAngle As Float) As B4XPath
	Dim cx As Float = pan.Width / 2
	Dim cy As Float = pan.Height / 2
	Dim rad As Float = pan.Height / 2 - gap
	Dim irad As Float = rad - gap
	Dim Angle As Float
	Dim path As B4XPath

	path.Initialize(cx + rad * Cos(startAngle), cy - rad * Sin(startAngle))
	For Angle = startAngle To finishAngle Step stp
		If Angle > finishAngle - stp Then
			Angle = finishAngle
		End If
		path.LineTo(cx + rad * Cos(Angle), cy - rad * Sin(Angle))
	Next
	For Angle = finishAngle To startAngle Step -stp
		If Angle < startAngle + stp Then
			Angle = startAngle
		End If
		path.LineTo(cx + irad * Cos(Angle), cy - irad * Sin(Angle))
	Next
	path.LineTo(cx + rad * Cos(startAngle), cy - rad * Sin(startAngle))
	Return path

End Sub

' Draw the fixed framework for the speed dial.
Sub DrawSpeedDial(pan As Panel, cvs As B4XCanvas)
	Dim path As B4XPath = SpeedDialPath(pan, -Pi / 4, 5 * Pi / 4)
	cvs.DrawPath(path, textColor, False, 2dip)
	
	' Draw the ticks every 5km/h
	Dim cx As Float = pan.Width / 2
	Dim cy As Float = pan.Height / 2
	Dim rad As Float = pan.Height / 2 - gap
	Dim orad As Float = rad + gap / 2
	Dim Spd As Int
	For Spd = 0 To 60 Step 5
		Dim Angle As Float= SpeedDialAngle(Spd * 10)
		Dim co As Float = Cos(Angle)
		Dim si As Float = Sin(Angle)
		cvs.DrawLine(cx + rad * co, cy - rad * si, cx + orad * co, cy - orad * si, textColor, 2dip)
	Next
	cvs.Invalidate
	
End Sub

' Calibration for speed stripe display.
' Calibration is a total angle range -3Pi/2 for 60km/h (hardcoded for now)
' Zero is 5pi/4. Negative because higher speeds are at smaller angles.
Sub SpeedDialAngle(Speedx10 As Int) As Float
	Dim Angle As Float = (5 * Pi / 4) - (Speedx10 / 600) * (3 * Pi / 2)
	Return Angle
End Sub

' Draw the speed stripe on the speed dial. 
Sub DrawSpeedStripe(pan As Panel, cvs As B4XCanvas, Speedx10 As Int)
	If Speedx10 == 0 Then
		Return
	Else If Speedx10 > 600 Then	' Dial tops out at 60km/h
		Speedx10 = 600
	End If
	Dim angleStart As Float = SpeedDialAngle(Speedx10)
	Dim path As B4XPath = SpeedDialPath(pan, angleStart, 5 * Pi / 4)
	cvs.DrawPath(path, Colors.Green, True, 0)
	'cvs.DrawPath(path, Colors.Green, False, 2dip)		' stroking for debugging
	cvs.Invalidate
	
End Sub

' Draw a speed marker in the given colour, for average/max speeds.
Sub DrawSpeedMark(pan As Panel, cvs As B4XCanvas, Speedx10 As Int, Color As Int)
	Dim hw As Int = 5 ' half width
	If Speedx10 <= hw Or Speedx10 >= 600 - hw Then
		Return
	End If
	Dim angleStart As Float = SpeedDialAngle(Speedx10 + hw)
	Dim angleFinish As Float = SpeedDialAngle(Speedx10 - hw)
	Dim path As B4XPath = SpeedDialPath(pan, angleStart, angleFinish)
	cvs.DrawPath(path, Color, True, 0)
	cvs.Invalidate
	
End Sub

'Draw a speed limit spot on the dial.
' If no speed limit packets have been received on the CAN bus, don't draw it.
' If the new speed limit has been set and a confirmation packet has not 
' been received, draw it in grey.
Sub DrawSpeedLimitSpot(pan As Panel, cvs As B4XCanvas)
	Dim cx As Float = pan.Width / 2
	Dim cy As Float = pan.Height / 2
	Dim rad As Float = pan.Height / 2 - gap
	If Not(SettingsValid) Then
		Return	' no information yet
	End If
	
	If NewSettingsValid And NewSpeedLimitx100 <> SpeedLimitx100 Then
		' Draw the spot in gray at the new limit. It will be redrawn
		' when the packet confirms the new limit has been accepted.
		DrawNumberPanelValue(pnlNewLimit, NewSpeedLimitx100, 100, 0, "")
		Dim Angle As Float = SpeedDialAngle(NewSpeedLimitx100 / 10)
		Dim x As Float = cx + rad * Cos(Angle)
		Dim y As Float = cy - rad * Sin(Angle)
		Dim r As Float = gap / 2
		cvs.DrawCircle(x, y, r, Colors.LightGray, True, 0)
		cvs.DrawCircle(x, y, r, Colors.Gray, False, 2dip)
	Else		' Just draw the red spot at current limit.
		Dim Angle As Float = SpeedDialAngle(SpeedLimitx100 / 10)
		Dim Angle As Float = SpeedDialAngle(SpeedLimitx100 / 10)
		Dim x As Float = cx + rad * Cos(Angle)
		Dim y As Float = cy - rad * Sin(Angle)
		Dim r As Float = gap / 2
		cvs.DrawCircle(x, y, r, Colors.White, True, 0)
		cvs.DrawCircle(x, y, r, Colors.Red, False, 2dip)
	End If
	cvs.Invalidate
	
End Sub

'--------------------------------------------------------------------------
' Interactions with speed dial to display menus, etc.

' Handle touches, etc. on the speed dial. Long presses via a timer.
' Only act on long presses if valid motor settings have been received.
Private Sub pnlSpeed_Touch(Action As Int, X As Float, Y As Float)
	Select Action
		Case pnlSpeed.ACTION_DOWN
			DownX = X
			DownY = Y
			longPressed = False
			LongPressTimer.Enabled = SettingsValid
			'Log("Down" & X & Y)
		Case pnlSpeed.ACTION_MOVE
			If Abs(X - DownX) > 30 Or Abs(Y - DownY) > 30 Then
				' You move, you lose. Disable the timer
				longPressed = False
				LongPressTimer.Enabled = False
				'Log("Moved" & X & Y)
				
				' reset timer and start again
				LongPressTimer.Enabled = SettingsValid
				DownX = X
				DownY = Y
			End If
		Case pnlSpeed.ACTION_UP
			' If timer has gone off and we're still pressing the button,
			' display the settings menu
			If longPressed Then
				'Log("Up")
				longPressed = False

				' Set the selections in Page 2 view lists
				Page2 = B4XPages.GetPage("Page 2")
				Page2.sel_limit = SpeedLimitx100
				Page2.sel_wheel = WheelSize124
				Page2.sel_circ = WheelCirc
				B4XPages.ShowPage("Page 2")
			End If
	End Select
End Sub

Private Sub LongPressTimer_Tick
	longPressed = True
	
	' Draw blue circle under finger
	' This doesn't work - it stays on screen when coming back?
	'cvsSpeed.DrawCircle(DownX, DownY, 50dip, 0xFF7EB4FA, True, 0)
	'cvsSpeed.Invalidate
End Sub

' Called from Page 2 to save selected settings and write them to the peripheral.
Public Sub WriteMotorSettings
	Dim b(7) As Byte

	NewSpeedLimitx100 = Page2.sel_limit
	NewWheelSize124 = Page2.sel_wheel
	NewWheelCirc = Page2.sel_circ
	NewSettingsValid = True
	
	b(0) = Bit.And(NewSpeedLimitx100, 0xFF)
	b(1) = Bit.And(Bit.ShiftRight(NewSpeedLimitx100, 8), 0xFF)
	b(2) = Bit.And(NewWheelCirc, 0xFF)
	b(3) = Bit.And(Bit.ShiftRight(NewWheelCirc, 8), 0xFF)
	b(4) = Bit.And(NewWheelSize124, 0xFF)
	b(5) = Bit.And(Bit.ShiftRight(NewWheelSize124, 8), 0xFF)
	b(6) = 1  ' NewSettingsValid
	
	Log("Writing " & bc.HexFromBytes(b) & " to " & settingsService & " " & settingsChar)
	Starter.manager.WriteData(settingsService, settingsChar, b)
	
End Sub

' Timer to update clock field
' Private Sub ClockTimer_Tick
' End Sub