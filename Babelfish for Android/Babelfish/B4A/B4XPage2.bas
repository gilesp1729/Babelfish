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

End Sub

Private Sub B4XPage_Appear

	B4XPages.SetTitle(Me, "Motor Settings")

End Sub

Private Sub B4XPage_Disappear

End Sub

