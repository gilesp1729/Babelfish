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
	Private SpeedIndex, WheelIndex As Int

	Public sel_limit, sel_wheel, sel_circ As Int
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
	' make the action bar show the Save button for this page only
	B4XPages.GetManager.ActionBar.RunMethod("setDisplayOptions", Array(16, 16))
	
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

		If sel_limit == i * 100 Then	' Highlight the currently selected speed limit
			SpeedIndex = SpeedLimits.Size - 1
			Highlight_Speed(SpeedIndex, True)

			' Bring highlighted item onto the screen
			' The Sleep is to allow the CLV to properly draw before scrolling it.
			' (the mysteries of Android...)
			Sleep(0)
			SpeedLimits.JumpToItem(SpeedIndex)
		End If
	Next
	
	' The wheel size/circ items have their values derived.
	' The inch size comes from the value (with special treatment of 700c, etc)
	' expressed in the usual 12.4 form (decimal bottom 4 bits)
	' The circumference comes directly from the third item.
	WheelSizes.Clear
	Dim diff_circ As Int
	Dim closest_circ As Int = 10000
	WheelIndex = 0
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
		
		' Each row stores the wheelsize in 12.4 and the circ in mm
		Dim val(2) As Int
		val(0) = float_to_124(inch)
		val(1) = row(2).As(Int)
		WheelSizes.Add(pn, val)
		
		' Determine the closest match in circumference, which is also
		' an exact match in wheel size. The input circumference might
		' not be an exact match if it was set by other software (like BESST)
		If val(0) == sel_wheel Then
			diff_circ = Abs(val(1) - sel_circ)
			If diff_circ < closest_circ Then
				closest_circ = diff_circ
				WheelIndex = WheelSizes.Size - 1
			End If
		End If
	Next
	
	' Highlight the closest match
	Highlight_Wheel(WheelIndex, True)
	
	' Bring highlighted item onto the screen
	Sleep(0)
	WheelSizes.JumpToItem(WheelIndex)
	
End Sub

Private Sub B4XPage_Disappear

End Sub

' Populate a wheel size list row from the CSV file row.
' The strings are inch size, ISO rim size and wheel circumference.
Private Sub FillWheelItem(row() As String) As Panel
	Dim pn As Panel
	pn.Initialize("")
	pn.SetLayout(0, 0, 300dip, 40dip) 
	
	lblWheelInch.Initialize("")
	lblWheelInch.Gravity = Gravity.CENTER_VERTICAL
	lblWheelInch.Padding = Array As Int(10dip, 0, 0, 0)
	pn.AddView(lblWheelInch, 0, 0, 180dip, 40dip)
	lblWheelISO.Initialize("")
	lblWheelISO.Gravity = Gravity.CENTER_VERTICAL
	pn.AddView(lblWheelISO, 180dip, 0, 60dip, 40dip)
	lblWheelCirc.Initialize("")
	lblWheelCirc.Gravity = Bit.Or(Gravity.RIGHT, Gravity.CENTER_VERTICAL)
	pn.AddView(lblWheelCirc, 240dip, 0, 60dip, 40dip)

	lblWheelInch.text = row(0)
	lblWheelISO.Text = row(1)
	lblWheelCirc.Text = row(2)
	
	lblWheelInch.As(B4XView).TextColor = textColor
	lblWheelISO.As(B4XView).TextColor = textColor
	lblWheelCirc.As(B4XView).TextColor = textColor
	
	Return pn

End Sub

' Highlight (or unhighlight) an item in the speed limit list.
Sub Highlight_Speed(index As Int, highlight As Boolean)
	Dim p = SpeedLimits.GetRawListItem(index).Panel.GetView(0) As B4XView
	Dim t As B4XView = p.GetView(0)
	If highlight Then
		p.SetColorAndBorder(textColor, 4dip, 0x00000000, 0)
		t.TextColor = bgndColor
	Else
		p.SetColorAndBorder(bgndColor, 4dip, 0x00000000, 0)
		t.TextColor = textColor
	End If

End Sub

' Highlight (or unhighlight) an item in the wheel size list.
Sub Highlight_Wheel(index As Int, highlight As Boolean)
	Dim P As B4XView
	p = WheelSizes.GetRawListItem(index).Panel.GetView(0)
	If highlight Then
		p.SetColorAndBorder(textColor, 4dip, 0x00000000, 0)
		p.GetView(0).TextColor = bgndColor
		p.GetView(1).TextColor = bgndColor
		p.GetView(2).TextColor = bgndColor
	Else
		p.SetColorAndBorder(bgndColor, 4dip, 0x00000000, 0)
		p.GetView(0).TextColor = textColor
		p.GetView(1).TextColor = textColor
		p.GetView(2).TextColor = textColor
	End If
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

Sub SpeedLimits_ItemClick(Index As Int, Value As Int)
	Log("Speed limit " & Value)
	sel_limit = Value
	Highlight_Speed(SpeedIndex, False)
	Highlight_Speed(Index, True)
	SpeedIndex = Index
End Sub
	
'Sub WheelSizes_ItemClick(Index As Int, Value As Object)
Sub WheelSizes_ItemClick(Index As Int, Value() As Int)
	Log("Wheel size " & Value(0))
	Log("Circumference " & Value(1))
	sel_wheel = Value(0)
	sel_circ = Value(1)
	Highlight_Wheel(WheelIndex, False)
	Highlight_Wheel(Index, True)
	WheelIndex = Index
End Sub

' Save button (pressed here, but event goes to Mainpage)
' sets Page1 variables, sends them back to the peripheral,
' and closes page2.
Public Sub SaveCallback
	Dim Page1 As B4XPage1 = B4XPages.GetPage("Page 1")
	Page1.WriteMotorSettings
	B4XPages.ClosePage(Me)
End Sub