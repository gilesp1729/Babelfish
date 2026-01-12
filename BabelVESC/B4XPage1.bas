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
	Public Provider As FileProvider
	
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
	Private settingsService As String
	Private settingsChar As String

	Private NewSpeedLimitx100 As Int
	Private NewWheelCirc As Int
	Private NewWheelSize124 As Int
	Private SettingsValid As Boolean = False
	
	' For catching long presses and triggering Page 2
	Private DownX, DownY As Float
	Private longPressed As Boolean
	Private LongPressTimer As Timer
	
	' For accumulating the average and max speeds and trip counter
	Private nSamples As Int
	Private Trip As Float
	Private prevLocation As Location
	
	' For rollups on rows of number panels
	Private VisibleRows As Int
	Private LargestRow As Int
	Private btnDoubleUp As B4XView
	Private btnDown As B4XView	
	Private btnDoubleDown As B4XView
	
	' For map deisplay
	Private MapFragment1 As MapFragment
	Private gmap As GoogleMap
	Private Poly As Polyline
	Private PolyPts As List
	Private btnDay As B4XView
	Private btnNight As B4XView
	
	' For logging
	Private Logger As TextWriter
	Dim Speedx100 As Int
	Dim cadence As Int
	Dim ampsx100 As Int
	Dim ampsreqx100 As Int
	Dim voltsx100 As Int
	Dim watts As Int
	Dim pas As Int
	Dim mtemp As Int
	Dim ctemp As Int

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
	PolyPts.Initialize
	Provider.Initialize
End Sub

'--------------------------------------------------------------------------
' Handle initial drawing of the page.

Private Sub B4XPage_Appear
	' Draw panels for quantities to be displayed

	' Set background panel to the background color
	pnlBackground.SetColorAndBorder(bgndColor, 0, borderColor, 0)

	' Set action bar to show the save button. Not used yet but might be for pause/resume later.
	MainPage = B4XPages.GetPage("MainPage")
	B4XPages.GetManager.ActionBar.RunMethod("setDisplayOptions", Array(16, 16))
	MainPage.btnSave.Text = "Not Used"	
	
	' Go through the list of services and find out what we are connected to.
	' 0 = no relevant services (we just use the GPS for speed)
	' 1 = CSC service found
	' 2 = CP service found
	' 3 = CP service found as well as the Babelfish custom motor service (0xFFF0)
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
		servList.Add(bfService)		' add 'em both, so BF can log avg/max from CP wheel revs/times
		servList.Add(cpService)
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

	Log("to device of type " & ConnectedDeviceType)
	
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
				
		' These sit on top of the speed dial panel, so transparent background.
		DrawNumberPanel(pnlBattery, "", "", True, 0)
		DrawNumberPanel(pnlPAS, "PAS", "", True, 0)
		DrawNumberPanel(pnlRange, "Range", "km", True, 0)
		DrawNumberPanel(pnlCadence, "", "rpm", True, 0)	' Don't show "cad" as it gets in the way of the speed dial
		DrawNumberPanel(pnlClock, "Time", "", True, 0)

		' The rest are lower down on  the page. 
		' They are not transparent, so they are numbered to allow the rows to be rolled up/down
		LargestRow = 5
		VisibleRows = 2
		DrawNumberPanel(pnlTrip, "Trip", "km", False, 1)	' row 1
		DrawNumberPanel(pnlMax, "Max", "km/h", False, 1)
		DrawNumberPanel(pnlAvg, "Avg", "km/h", False, 1)

		DrawNumberPanel(pnlPower, "Power", "", False, 2)	' row 2
		DrawNumberPanel(pnlVolts, "Volts", "", False, 2)
		DrawNumberPanel(pnlAmps, "Amps", "", False, 2)

		DrawNumberPanel(pnlLimit, "Limit", "km/h", False, 3)	' row 3
		DrawNumberPanel(pnlWheelSize, "ReqAmps", "", False, 3)				' requested amps
		DrawNumberPanel(pnlCirc, "Circ", "mm", False, 3)

		DrawNumberPanel(pnlNewLimit, "Motor", "", False, 4)	' row 4			' motor temp
		DrawNumberPanel(pnlNewWheelSize, "Ctrl", "", False, 4)				' ctrlr temp
		DrawNumberPanelBlank(pnlNewCirc)
		
		DrawNumberPanel(pnlOdo, "CP km/h", "km/h", False, 5)		' row 5			' CP speed (to compare with BF speed for sanity check)
		
		' Start logging the data to the log file.
		Logger.Initialize(File.OpenOutput(File.DirInternal, "BabelVESC.csv", False))
		Logger.WriteLine("WheelTime,WheelRev,Speed,Cadence,Power,PAS,Volts,Amps,ReqAmps,MotorTemp,CtrlTemp")

	Else if ConnectedDeviceType == 2 Then
		UpdateTimer.Enabled = True

		' Set up for CP service
		ClearSpeedDial(pnlSpeed, cvsSpeed, "Speed", "km/h")
		DrawSpeedDial(pnlSpeed, cvsSpeed)

		DrawNumberPanel(pnlBattery, "", "", True, 0)
		DrawNumberPanel(pnlCadence, "", "rpm", True, 0)	' Don't show "cad" as it gets in the way of the speed dial
		DrawNumberPanel(pnlPAS, "Power", "", True, 0)		' Use PAS field for power to keep it neat.
		DrawNumberPanel(pnlClock, "Time", "", True, 0)

		LargestRow = 1
		VisibleRows = 1
		DrawNumberPanel(pnlTrip, "Trip", "km", False, 1)	' These are calculated values
		DrawNumberPanel(pnlMax, "Max", "km/h", False, 1)
		DrawNumberPanel(pnlAvg, "Avg", "km/h", False, 1)
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

		DrawNumberPanel(pnlBattery, "", "", True, 0)
		DrawNumberPanel(pnlCadence, "", "rpm", True, 0)	' Don't show "cad" as it gets in the way of the speed dial
		DrawNumberPanel(pnlClock, "Time", "", True, 0)

		LargestRow = 1
		VisibleRows = 1
		DrawNumberPanel(pnlTrip, "Trip", "km", False, 1)
		DrawNumberPanel(pnlMax, "Max", "km/h", False, 1)
		DrawNumberPanel(pnlAvg, "Avg", "km/h", False, 1)
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
		DrawNumberPanel(pnlClock, "Time", "", True, 0)

		LargestRow = 1
		VisibleRows = 1
		DrawNumberPanel(pnlTrip, "Trip", "km", False, 1)
		DrawNumberPanel(pnlMax, "Max", "km/h", False, 1)
		DrawNumberPanel(pnlAvg, "Avg", "km/h", False, 1)
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
	
	' Not strictly required but ensures all invisible panels don't respond
	' to touches.
	ShowHideAllPanels
	
	' Draw the buttons.
	DrawButton(btnDoubleUp)
	DrawButton(btnDown)
	DrawButton(btnDoubleDown)
	DrawButton(btnDay)
	DrawButton(btnNight)

	' Start GPS. Updates no more than every 500ms, and after 1 metre of movement.
	Log("Starting GNSS")
	MainPage.Gnss1.Start(500, 1.0)

	' Set up map fragment. Do this now so the screen isn't messy whle waiting
	
	' Warning: This doesn't ever come back when re-entering (the event never comes)
	' Wait For MapFragment1_Ready
	' Do a positive test for an initialised map every time instead.
	gmap = MapFragment1.GetMap
	Do While gmap.IsInitialized = False
		Sleep(100)
		gmap = MapFragment1.GetMap
	Loop
	Log("Enabling my location")
	gmap.MyLocationEnabled = True
	Do While gmap.MyLocation.IsInitialized = False
		Sleep(100)
	Loop
	
	' Put me in the centre of the map
	Dim cp As CameraPosition
	cp.Initialize(gmap.MyLocation.Latitude, gmap.MyLocation.Longitude, 16)
	Log("Setting camera position")
	gmap.MoveCamera(cp)
	
	' Start maps in night mode
	btnNight_Click
	
	' Clear the average/max speed and trip distance.
	Log("Clearing avg/max/trip")
	ZeroTripMaxAvg
	
End Sub

Private Sub B4XPage_Disappear
	Log ("Page 1 disappear")
	UpdateTimer.Enabled = False
	MainPage.Gnss1.Stop
	If ConnectedDeviceType == 3 Then
		Logger.Close
		'Log("Log file size: " & File.Size(File.DirInternal, "BabelVESC.csv"))
		
		' Save the file to someplace sensible by sharing it.
		' Date/time code  to generate a unique filename to save
		Dim filename As String
		DateTime.DateFormat = "yyyyMMdd"
		DateTime.TimeFormat = "HHmmss"
		filename = "BabelVESC-" & DateTime.Date(DateTime.Now) & "-" & DateTime.Time(DateTime.Now) & ".csv"
		
		File.Copy(File.DirInternal, "BabelVESC.csv", Provider.SharedFolder, filename)
		Dim in As Intent
		in.Initialize(in.ACTION_SEND, "")
		in.SetType("text/plain")
		in.PutExtra("android.intent.extra.STREAM", Provider.GetFileUri(filename))
		in.Flags = 1 'FLAG_GRANT_READ_URI_PERMISSION
		StartActivity(in)
	End If
End Sub

'--------------------------------------------------------------------------
' Handle repeated reading of GPS fix.
' This is called whenever the location changes.

Sub Gnss1_LocationChanged (Location1 As Location)

	' Throw away results that are not accurate (wait for GPS to settle down before drawing lines)
	' Fine location typically gets to within ~5m.
	If Not(Location1.AccuracyValid) Then
		Return
	End If
	If Location1.Accuracy > 10.0 Then
		Return
	End If

	If ConnectedDeviceType == 0 Then
		' GPS bike only (others have their own speed data source)
		
		If Location1.SpeedValid Then
			ClearSpeedDial(pnlSpeed, cvsSpeed, "Speed", "km/h")
			DrawSpeedDial(pnlSpeed, cvsSpeed)
			Dim Speedx100 As Int = Location1.Speed * 360
			DrawSpeedPanelValue(Speedx100, 100)
			DrawSpeedStripe(pnlSpeed, cvsSpeed, Speedx100 / 10)
			DrawSpeedMark(pnlSpeed, cvsSpeed, MaxSpdx10, Colors.Red)
			DrawSpeedMark(pnlSpeed, cvsSpeed, AvgSpdx10, Colors.Yellow)

			' Update trip counter, max and average speeds.
			Dim Dist As Float = 0
			If nSamples > 0 Then
				Dist = Location1.DistanceTo(prevLocation) / 1000
			End If
			UpdateTripMaxAvg(Dist, Location1.Speed * 3.6)
		End If

		' While here, update the clock.
		DateTime.TimeFormat = "HH:mm"
		DrawStringPanelValue(pnlClock, DateTime.Time(DateTime.Now))
	End If
	
	' All devices:
	' Try out bearing-up orientation of the map.
	' TODO: make the bearings running averages, or something? The map is too jittery.
	Dim cp As CameraPosition
	cp.Initialize2(Location1.Latitude, Location1.Longitude, gmap.CameraPosition.Zoom, prevLocation.BearingTo(Location1), 0)
	gmap.MoveCamera(cp)

	' Add the new point to the list, then clear and re-display it as a new Polyline.
	Dim LL As LatLng
	LL.Initialize(Location1.Latitude, Location1.Longitude)
	PolyPts.Add(LL)
	If PolyPts.Size >= 2 Then
		gmap.Clear
		Poly = gmap.AddPolyline
		Poly.Color = Colors.Blue
		Poly.Points = PolyPts
	End If
	prevLocation = Location1

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

' Set night and day modes in map.
Sub btnNight_Click
	Dim jo As JavaObject = gmap
	Dim style As JavaObject
	style.InitializeNewInstance("com.google.android.gms.maps.model.MapStyleOptions", Array(File.ReadString(File.DirAssets, "NightMode.json")))
	Log("Night Mode " & jo.RunMethod("setMapStyle", Array(style))) 'returns True if successful
End Sub

Sub btnDay_Click
	Dim jo As JavaObject = gmap
	Dim style As JavaObject
	style.InitializeNewInstance("com.google.android.gms.maps.model.MapStyleOptions", Array("[]"))	' set default options
	Log("Day Mode " & jo.RunMethod("setMapStyle", Array(style)))
End Sub

'--------------------------------------------------------------------------
' Update the trip, max and average speeds, for devices that do not supply these values directly.
' TODO calculate the range in here too.
Sub UpdateTripMaxAvg(dist As Float, speed As Float)
	Dim spdx10 As Int = speed * 10
	
	Trip = Trip + dist
	If spdx10 > MaxSpdx10 Then
		MaxSpdx10 = spdx10
	End If
	AvgSpdx10 = ((AvgSpdx10 * nSamples) + spdx10) / (nSamples + 1)
	nSamples = nSamples + 1

	DrawNumberPanelValue(pnlTrip, (Trip * 10).As(Int), 10, 0, "")
	DrawNumberPanelValue(pnlMax, MaxSpdx10, 10, 0, "")
	DrawNumberPanelValue(pnlAvg, AvgSpdx10, 10, 1, "")
End Sub

' Zero the trip, max and average fields. Clear any displayed track on the map.
Sub ZeroTripMaxAvg
	nSamples = 0
	AvgSpdx10 = 0
	MaxSpdx10 = 0
	Trip = 0
	prevLocation.Initialize
	PolyPts.Clear
	gmap.Clear	
End Sub

'--------------------------------------------------------------------------
' Handle repeated reading of characteristics from the connected peripheral
' handle reconnection attempts if the BLE connect is broken for any reason.
Sub UpdateTimer_Tick

	If Not(Starter.Connected) Then
		Log("Connection lost, reconnecting...")
#if B4A
	Starter.manager.Connect2(Starter.ConnectedId, False)
#else if B4I
	manager.Connect(Starter.ConnectedId)
#end if
		B4XPages.SetTitle(Me, "Reconnecting...")  ' Manager.Connect will reinstate title
		Return
	End If

	' When timer fires, read all the characteristics for all the wanted services.
	For Each s As String In servList
		'Log("ReadData from " & s)
		Starter.manager.ReadData(s)
	Next
	
	' While here, update the clock.
	DateTime.TimeFormat = "HH:mm"
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
				Speedx100 = Unsigned2(b(0), b(1))
				ClearSpeedDial(pnlSpeed, cvsSpeed, "Speed", "km/h")
				DrawSpeedDial(pnlSpeed, cvsSpeed)
				DrawSpeedPanelValue(Speedx100, 100)
				DrawSpeedStripe(pnlSpeed, cvsSpeed, Speedx100 / 10)
				' Draw things that have to appear on top of the speed stripe
				DrawSpeedMark(pnlSpeed, cvsSpeed, MaxSpdx10, Colors.Red)
				DrawSpeedMark(pnlSpeed, cvsSpeed, AvgSpdx10, Colors.Yellow)
				DrawSpeedLimitSpot(pnlSpeed, cvsSpeed)
				cadence = Unsigned(b(2))
				DrawNumberPanelValue(pnlCadence, cadence, 1, 0, "")
				ampsreqx100 = Unsigned2(b(9), b(10))
				DrawNumberPanelValue(pnlWheelSize, ampsreqx100, 100, 1, "A")	' requested amps

				watts = Unsigned2(b(3), b(4))
				DrawNumberPanelValue(pnlPower, watts, 1, 0, "W")
				voltsx100 = Unsigned2(b(5), b(6))
				DrawNumberPanelValue(pnlVolts, voltsx100, 100, 1, "V")
				ampsx100 = Unsigned2(b(7), b(8))
				DrawNumberPanelValue(pnlAmps, ampsx100, 100, 1, "A")
				' Note these are signed as they might be negative (brrrr...)
				' TODO fix the names of the fields.
				mtemp = b(12) - 40
				DrawNumberPanelValue(pnlNewLimit, mtemp, 1, 0, "C")			' motor temp
				ctemp = b(13) - 40
				DrawNumberPanelValue(pnlNewWheelSize, ctemp, 1, 0, "C")		' controller temp
				pas = Unsigned(b(11))
				DrawStringPanelValue(pnlPAS, PASLevels(pas))
				
			else If id.ToLowerCase.StartsWith("0000fff2") Then
				' Motor settings. 
				SpeedLimitx100 = Unsigned2(b(0), b(1))
				DrawNumberPanelValue(pnlLimit, SpeedLimitx100, 100, 0, "")
				WheelCirc = Unsigned2(b(2), b(3))
				DrawNumberPanelValue(pnlCirc, WheelCirc, 1, 0, "")

			else If id.ToLowerCase.StartsWith("0000fff3") Then						' TODO remove this when decided how to do it
				' Writable new settings. Remember the service and char ID's for later writing
				settingsService = ServiceId
				settingsChar = id
				
			else If id.ToLowerCase.StartsWith("00002a63") Then
				' CP measurement yields wheel revs and times. Use these to update the max/avg
				' since we don't have the CAN bus controller any more
				' Wheel revolutions and wheel time
				Dim wheelRev As Int = Unsigned4(b(4), b(5), b(6), b(7))
				Dim wheelTime As Int = Unsigned2(b(8), b(9)) / 2	' Half-ms, don't forget
				If lastWheelRev == 0 Then
					lastWheelRev = wheelRev
				End If
				If (wheelTime - lastWheelTime > 0) Then
					' The division yields mm/ms (=m/s). Convert it to km/h*10
					Dim Speedx10 As Int = ((wheelRev - lastWheelRev) * WheelCirc * 36) / (wheelTime - lastWheelTime)
					UpdateTripMaxAvg(((wheelRev - lastWheelRev) * WheelCirc).As(Float) / 1000000, Speedx10.As(Float) / 10)
					
					' The wheel time has advanced, so write a line out to the log file. Handle float conversions.
					' Catch any updates that sneak in just after the page has disappeared (the logger has been closed
					' and attempts to write to it will crash)
					If UpdateTimer.Enabled Then
						Dim speed As Float = Speedx100 / 100.0
						Dim volts As Float = voltsx100 / 100.0					
						Dim amps As Float = ampsx100 / 100.0
						Dim ampsreq As Float = ampsreqx100 / 100.0
						' (WheelTime,WheelRev,Speed,Cadence,Power,PAS,Volts,Amps,ReqAmps,MotorTemp,CtrlTemp)
						Logger.Write("" & wheelTime)
						Logger.Write("," & wheelRev)
						Logger.Write("," & speed)
						Logger.Write("," & cadence)
						Logger.Write("," & watts)
						Logger.Write("," & pas)
						Logger.Write("," & volts)
						Logger.Write("," & amps)
						Logger.Write("," & ampsreq)
						Logger.Write("," & mtemp)
						Logger.WriteLine("," & ctemp)
					End If
										
					' Just for a sanity check, write out wheeltime/rev speed to cmpare with Farnsworth speed. They should agree.
					DrawNumberPanelValue(pnlOdo, Speedx10, 10, 0, "")
				End If
				lastWheelRev = wheelRev
				lastWheelTime = wheelTime

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
					DrawSpeedPanelValue(Speedx10, 10)
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
					DrawSpeedPanelValue(Speedx10, 10)
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
' The row number, if nonzero, allows them to be rolled up or down.
' DO NOT use with graphics like the speed dial (the SetColorAndBorder will clobber them)
Sub DrawNumberPanel(pan As B4XView, Name As String, Unit As String, transparent As Boolean, row As Int)
	Dim N As B4XView = pan.GetView(0)
	Dim U As B4XView = pan.GetView(1)
	Dim V As B4XView = pan.GetView(2)
	If transparent Then
		pan.SetColorAndBorder(Bit.And(bgndColor, 0x00FFFFFF), 0, borderColor, 0)
	Else
		'semitransparent for map overlay
		pan.SetColorAndBorder(Bit.And(bgndColor, 0x40FFFFFF), 2dip, Bit.And(borderColor, 0x40FFFFFF), 0)
	End If
	N.TextColor = textColor
	U.TextColor = textColor
	V.TextColor = textColor
	N.Text = Name
	U.Text = Unit
	V.Text = "--"

	' Set the row number and decide whether it should be initially visible.
	pan.Tag = row
	ShowHidePanel(pan)
End Sub

' Draw a button with transparent background.
Sub DrawButton(btn As B4XView)
	btn.SetColorAndBorder(Bit.And(bgndColor, 0x00FFFFFF), 0, borderColor, 0)
	btn.TextColor = textColor
End Sub

' Draw the value in a number panel. Optionally append a unit when it would 
' look better that way (like a battery percentage)
Sub DrawNumberPanelValue(pan As B4XView, Value As Int, Div As Int, Decpl As Int, Append As String)
	Dim V As B4XView = pan.GetView(2)
	Dim fval As Float = Value / Div
	' Divide by the division factor (e.g. 10 or 100) before displaying.
	' Format the fval with Decpl places. Append any optional string.
	V.Text = NumberFormat2(fval, 1, Decpl, 0, False) & Append
End Sub

' Draw the value in a number panel. Special case for speed with optional dec place 
' for small numbers (like speed 8.5, 9.5, but 10, 20... with no decimal point)
Sub DrawSpeedPanelValue(Value As Int, Div As Int)
	Dim V As B4XView = pnlSpeed.GetView(2)
	Dim fval As Float = Value / Div
	If fval >= 10 Then
		V.Text = NumberFormat2(fval, 1, 0, 0, False)
	Else	' one dec place for single digit speeds
		V.Text = NumberFormat2(fval, 1, 1, 1, False)
	End If
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
	' (not necessary) V.TextColor = textColor
	V.Text = str	
End Sub

' Fill a number panel with a blank background. Set its row number so it can never be
' rolled up/down.
Sub DrawNumberPanelBlank(pan As B4XView)
	pan.SetColorAndBorder(Bit.And(bgndColor, 0x00FFFFFF), 0, borderColor, 0)
	pan.Tag = 99		' higher than any row possible
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
Sub DrawSpeedLimitSpot(pan As Panel, cvs As B4XCanvas)
	Dim cx As Float = pan.Width / 2
	Dim cy As Float = pan.Height / 2
	Dim rad As Float = pan.Height / 2 - gap
	If Not(SettingsValid) Then
		Return	' no information yet
	End If
	
	Dim Angle As Float = SpeedDialAngle(SpeedLimitx100 / 10)
	Dim x As Float = cx + rad * Cos(Angle)
	Dim y As Float = cy - rad * Sin(Angle)
	Dim r As Float = gap / 2
	cvs.DrawCircle(x, y, r, Colors.White, True, 0)
	cvs.DrawCircle(x, y, r, Colors.Red, False, 2dip)
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
				Page2.sel_wheel = 0		'' TODO get rid of all this stuff
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
	
	b(0) = Bit.And(NewSpeedLimitx100, 0xFF)
	b(1) = Bit.And(Bit.ShiftRight(NewSpeedLimitx100, 8), 0xFF)
	b(2) = Bit.And(NewWheelCirc, 0xFF)
	b(3) = Bit.And(Bit.ShiftRight(NewWheelCirc, 8), 0xFF)
	b(4) = Bit.And(NewWheelSize124, 0xFF)
	b(5) = Bit.And(Bit.ShiftRight(NewWheelSize124, 8), 0xFF)
	
	Log("Writing " & bc.HexFromBytes(b) & " to " & settingsService & " " & settingsChar)
	Starter.manager.WriteData(settingsService, settingsChar, b)
	
End Sub

'--------------------------------------------------------------------------
' Handle rollup/down of panels.

' Show all panel rows up to VisibleRow, and hide those beyond that.
Sub ShowHidePanel(pan As Panel)
	pan.Visible = pan.Tag.As(Int) <= VisibleRows
End Sub

' Show/hide all panels.
Sub ShowHideAllPanels
	ShowHidePanel(pnlTrip)
	ShowHidePanel(pnlMax)
	ShowHidePanel(pnlAvg)

	ShowHidePanel(pnlPower)
	ShowHidePanel(pnlVolts)
	ShowHidePanel(pnlAmps)

	ShowHidePanel(pnlLimit)
	ShowHidePanel(pnlWheelSize)
	ShowHidePanel(pnlCirc)

	ShowHidePanel(pnlNewLimit)
	ShowHidePanel(pnlNewWheelSize)
	ShowHidePanel(pnlNewCirc)
		
	ShowHidePanel(pnlOdo)

End Sub

' Process button presses.
Sub btnDoubleUp_Click
	VisibleRows = 0
	ShowHideAllPanels
End Sub

Sub btnDown_Click
	VisibleRows = LargestRow
	If LargestRow > 2 Then
		VisibleRows = 2
	End If
	ShowHideAllPanels
End Sub

Sub btnDoubleDown_Click
	VisibleRows = LargestRow
	ShowHideAllPanels
End Sub

