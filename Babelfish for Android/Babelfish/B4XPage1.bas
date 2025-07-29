B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=8.5
@EndOfDesignText@
Sub Class_Globals
	Private Root As B4XView 'ignore
	Private xui As XUI 'ignore
	
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
End Sub

Private Sub B4XPage_Appear

End Sub

Private Sub B4XPage_Disappear
	' when going back, disconnect babelfish peripheral
	'manager.Disconnect
	'Manager_Disconnected

End Sub

'You can see the list of page related events in the B4XPagesManager object. The event name is B4XPage.


