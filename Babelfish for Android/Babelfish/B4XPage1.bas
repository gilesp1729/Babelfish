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
	
	bgndColor = Starter.bgndColor
	borderColor = Starter.borderColor
	textColor = Starter.textColor

End Sub

Private Sub B4XPage_Appear
	' Draw panels for quantities to be displayed
	DrawNumberPanel(pnlSpeed, "Speed", "km/h")
	' Deterine if it's a CSC, CP, or babelfish
	' Set notification listener up
End Sub

Private Sub B4XPage_Disappear
	' Stop the notification listener
End Sub

'You can see the list of page related events in the B4XPagesManager object. The event name is B4XPage.

' Notification listener subroutine
' Read chas and update numbers on screen
' Standard function to updtae a tile

' Draw a number panel. There are three standard labels in the panel:
' 0 = Name
' 1 = unit
' 2 = Value
' As drawn, the value is set to "--". 
Sub DrawNumberPanel(pan As B4XView, Name As String, Unit As String)
	Dim N As B4XView = pan.GetView(0)
	Dim U As B4XView = pan.GetView(1)
	Dim V As B4XView = pan.GetView(2)
	pan.SetColorAndBorder(bgndColor, 2dip, borderColor, 0)
	N.TextColor = textColor
	U.TextColor = textColor
	V.TextColor = textColor
	N.Text = Name
	U.Text = Unit
	V.Text = "100"
End Sub