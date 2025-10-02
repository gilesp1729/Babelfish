﻿B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Service
Version=13.1
@EndOfDesignText@
#Region  Service Attributes 
	#StartAtBoot: False
	#ExcludeFromLibrary: True
#End Region

Sub Process_Globals
	'These global variables will be declared once when the application starts.
	'These variables can be accessed from all modules.
	#if B4A
	Public manager As BleManager2
	#else if B4i
	Public manager As BleManager
	#end if
	Public Connected As Boolean
	Public ConnectedName As String
	Public ConnectedId As String
	Public ConnectedServices As List
	
	' Colors
	Public bgndColor = 0xFF000000 As Int
	Public borderColor  = 0xFF808080 As Int
	Public textColor = 0xFFFFFFBF As Int
End Sub

Sub Service_Create
	'This is the program entry point.
	'This is a good place to load resources that are not specific to a single activity.

End Sub

Sub Service_Start (StartingIntent As Intent)
	Service.StopAutomaticForeground 'Starter service can start in the foreground state in some edge cases.
End Sub

Sub Service_TaskRemoved
	'This event will be raised when the user removes the app from the recent apps list.
End Sub

'Return true to allow the OS default exceptions handler to handle the uncaught exception.
Sub Application_Error (Error As Exception, StackTrace As String) As Boolean
	Return True
End Sub

Sub Service_Destroy

End Sub
