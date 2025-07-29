B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.85
@EndOfDesignText@
#Region Shared Files
#CustomBuildAction: folders ready, %WINDIR%\System32\Robocopy.exe,"..\..\Shared Files" "..\Files"
'Ctrl + click to sync files: ide://run?file=%WINDIR%\System32\Robocopy.exe&args=..\..\Shared+Files&args=..\Files&FilesSync=True
#End Region

'Ctrl + click to export as zip: ide://run?File=%B4X%\Zipper.jar&Args=B4XTwoPages.zip

Sub Class_Globals
	Private Root As B4XView
	Private xui As XUI
	
	Private Page1 As B4XPage1
	
	Private ConnectedName As String
	Private ConnectedId As String
	Private btnScanAndConnect As B4XView
	Private Connected As Boolean
	Private DeviceFound As Boolean
	
	#if B4A
	Private manager As BleManager2
	Private rp As RuntimePermissions
	#else if B4i
	Private manager As BleManager
	#end if
	Private ConnectedServices As List
	'Private pbScan As B4XLoadingIndicator

End Sub

Public Sub Initialize
	Log("MainPage Init")
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Log("MainPage Create")
	
	Root = Root1
	Root.LoadLayout("MainPage")
	B4XPages.SetTitle(Me, "Babelfish")
	manager.Initialize("manager")
	
	Page1.Initialize	'initializes Page1
	B4XPages.AddPage("Page 1", Page1)	'adds Page1 to the B4XPages list

	btnScanAndConnect.Text = "Scan for devices"
	Connected = False
	DeviceFound = False
End Sub

'You can see the list of page related events in the B4XPagesManager object. The event name is B4XPage.
'Display Page1


Sub Manager_DeviceFound (Name As String, Id As String, AdvertisingData As Map, RSSI As Double)
	Log("Found: " & Name & ", " & Id & ", RSSI = " & RSSI & ", " & AdvertisingData) 'ignore
	
	' Look for Babelfish instances. TODO: Put these in a list. And scan for that 0xFFF0 service!
	If Not(Name.StartsWith("Babelfish")) Then
		Return
	End If
		
	ConnectedName = Name
	ConnectedId = Id
	DeviceFound = True
	btnScanAndConnect.Text = ConnectedName
	manager.StopScan
End Sub

Sub Manager_Disconnected
	Log("Disconnected")
	Connected = False
End Sub

Sub Manager_Connected (services As List)
	Log("Connected")
	Connected = True
	ConnectedServices = services
	' Throw to Page 1
	B4XPages.ShowPage("Page 1")
	'Can only set title after page is shown.
	B4XPages.SetTitle(Page1, ConnectedName)
End Sub


Private Sub btnScanAndConnect_Click
	
	' if not connected - scan for devices bearing service 0xFFF0
	' connect to the device and change button text (that stays there
	' during this run of the app,until Rescan buttton pressed)
	If Not(DeviceFound) Then
	#if B4A
		'Don't forget to add permission to manifest
		Dim Permissions As List
		Dim phone As Phone
		If phone.SdkVersion >= 31 Then
			Permissions = Array("android.permission.BLUETOOTH_SCAN", "android.permission.BLUETOOTH_CONNECT", rp.PERMISSION_ACCESS_FINE_LOCATION)
		Else
			Permissions = Array(rp.PERMISSION_ACCESS_FINE_LOCATION)
		End If
		For Each per As String In Permissions
			rp.CheckAndRequest(per)
			Wait For B4XPage_PermissionResult (Permission As String, Result As Boolean)
			If Result = False Then
				ToastMessageShow("No permission: " & Permission, True)
				Return
			End If
		Next
	#end if
		manager.Scan2(Null, False)
		'manager.Scan2(0xFFF0, False)	' TODO: is this the right way to specifiy service?
		Return
	End If
	
	' if connected - connect to the device and throw us to Page1
	Log("connecting")
	#if B4A
	manager.Connect2(ConnectedId, False) 'disabling auto connect can make the connection quicker
	#else if B4I
	manager.Connect(Id)
	#end if
End Sub

Private Sub btnRescan_Click
	btnScanAndConnect.Text = "Scan for devices"
	DeviceFound = False
End Sub

