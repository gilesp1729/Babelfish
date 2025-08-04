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
	' The ReadData will trigger a DataAvailable event, but only if it's caught in the MainPage..	
	For Each s As String In Starter.ConnectedServices
		' TODO distiguish between BF+CP, CP or CSC, and set up lists of services
		' appropriate to each.
		If s.ToLowerCase.StartsWith("0000fff0") Then
			Log("Reading BF " & s)
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

			' TODO all the other panels for FFF0 - Babelfish Motor Service
			
			' TODO detect CP or CSC and do them with a different list of serv
		End If
	Next
End Sub

Private Sub B4XPage_Disappear
	UpdateTimer.Enabled = False
End Sub

' When timer fires, read all the characteristics
' TODO make this a bit more specific so we aren't reading everything every time
Sub UpdateTimer_Tick
	For Each s As String In Starter.ConnectedServices
		Starter.manager.ReadData(s)
	Next
End Sub

' Unsigned byte helper
Sub Unsigned(b As Byte) As Int
	Return Bit.And(0xFF, b)
End Sub

Sub Unsigned2(b0 As Byte, b1 As Byte) As Int
	Return Bit.Or(Bit.ShiftLeft(Unsigned(b1), 8), Unsigned(b0))
End Sub


' Callback for DataAvailable event (caught in main page?!)
Sub AvailCallback(ServiceId As String, Characteristics As Map)
	Dim b(20) As Byte
	Dim battIcon As String
	
	' Log("Service " & ServiceId)
	For Each id As String In Characteristics.Keys
		' Log("Char ID " & id)
		b = Characteristics.Get(id)
		' Log(bc.HexFromBytes(b))
		
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
				
		else If id.ToLowerCase.StartsWith("00002a19") Then
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
		pan.SetColorAndBorder(Bit.AndLong(bgndColor, 0x00FFFFFF), 0, borderColor, 0)
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
	V.Text = str	
End Sub