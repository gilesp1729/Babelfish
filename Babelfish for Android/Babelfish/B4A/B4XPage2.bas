B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=13.1
@EndOfDesignText@
Sub Class_Globals
	Private Root As B4XView 'ignore
	Private xui As XUI 'ignore
	
	Private bgndColor As Int
	Private borderColor As Int
	Private textColor As Int
	Private pnlBackground As B4XView
	
	Private WheelTable As List
	Private WheelSizes As CustomListView
	Private lblWheelInch As Label
	Private lblWheelISO As Label
	Private lblWheelCirc As Label
	Private lblWheelSizeAndCirc As Label

	Private SpeedLimits As CustomListView
	Private lblSpeedLimit As Label

End Sub

'You can add more parameters here.
Public Sub Initialize As Object
	Return Me
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	'load the layout to Root
	Root.LoadLayout("Page2")

	bgndColor = Starter.bgndColor
	borderColor = Starter.borderColor
	textColor = Starter.textColor
	
	' Read wheel/tyre size information from csv file. Skip the header row.
	' Tyre sizes from Wahoo web site
	Dim parser As CSVParser
	parser.Initialize
	WheelTable = parser.Parse(File.ReadString(File.DirAssets, "TyreSizes.csv"), ",", True)

End Sub

Private Sub B4XPage_Appear
	pnlBackground.SetColorAndBorder(bgndColor, 0, borderColor, 0)
	B4XPages.SetTitle(Me, "Motor Settings")

	' The speed limit items have values hardcoded directly in km/h x 100.
	SpeedLimits.Clear
	lblSpeedLimit.As(B4XView).TextColor = textColor
	For i = 25 To 45 Step 5
		SpeedLimits.AddTextItem("  " & i.As(String) & "km/h", i * 100)
		Dim p = SpeedLimits.GetRawListItem(SpeedLimits.Size - 1).Panel.GetView(0) As B4XView
		Dim t As B4XView = p.GetView(0)
		p.SetColorAndBorder(bgndColor, 4dip, 0x00000000, 0)
		t.TextColor = textColor
	Next
	
	' The wheel size/circ items have their values derived.
	' The inch size comes from the value (with special treatment of 700c, etc)
	' expressed in the usual 12.4 form (decimal bottom 4 bits)
	' The circumference comes directly from the third item.
	WheelSizes.Clear
	lblWheelSizeAndCirc.As(B4XView).TextColor = textColor
	For Each row() As String In WheelTable
		'Log(row(0))		' inch size
		'Log(row(1))		' ISO rim size
		'Log(row(2))		' circ in mm
		Dim pn As Panel = FillWheelItem(row)
		' translate the numeric part at the start of the string as float
		Dim inch As Float = string_to_float(row(0))
		If inch > 100 Then		' it's 650c, 700c etc. Divide to get an inch size
			inch = inch / 25.4
		End If
		'Log("in inches " & inch)
		WheelSizes.Add(pn, float_to_124(inch))
	Next

End Sub

Private Sub B4XPage_Disappear

End Sub

' Populate a wheel size list row from the CSV file row.
' The strings are inch size, ISO rim size and wheel circumference.
Private Sub FillWheelItem(row() As String) As Panel
	Dim pn As Panel
	pn.Initialize("")
	pn.SetLayoutAnimated(0, 0dip, 0dip, 320dip,40dip)  ' TODO This is messing up the border.
	pn.LoadLayout("wheelitem_layout")
	lblWheelInch.text = row(0)
	lblWheelISO.Text = row(1)
	lblWheelCirc.Text = row(2)
	
	pn.As(B4XView).SetColorAndBorder(bgndColor, 4dip, 0x00000000, 0)
	lblWheelInch.As(B4XView).TextColor = textColor
	lblWheelISO.As(B4XView).TextColor = textColor
	lblWheelCirc.As(B4XView).TextColor = textColor
	
	Return pn

End Sub

' Convert a float to an int in 12.4 with decimal bottom nibble.
' e.g. 27.5 --> 0x1B.5 --> 0x1B5
'        29 --> 0x1D.0 --> 0x1D0
Private Sub float_to_124(inch As Float) As Int
	Dim intg As Int = Floor(inch)
	Dim frac As Int = (inch - intg) * 10
	'Log("in 12.4 " & (intg * 16 + frac))
	Return intg * 16 + frac
End Sub

' Extract a float from the beginning of the string, stopping
' at the first non-numeric character.
Private Sub string_to_float(str As String) As Float
	Dim last As Int = 0
	For i = 0 To str.Length
		Dim ch As Char = str.CharAt(i)
		If Not(".0123456789".Contains(ch)) Then
			last = i
			Exit
		End If
	Next
	Return str.SubString2(0, last).As(Float)
End Sub

