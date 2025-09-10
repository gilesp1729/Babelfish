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
	Private Page2 As B4XPage2
	
	Private ConnectedName As String
	Private ConnectedId As String
	Private ConnectedIndex As Int
	Private btnScanAndConnect As B4XView
	Private clv As CustomListView	
	Private Connected As Boolean
	Private ScanTimer As Timer
	Private ConnectTimer As Timer
	Private ToastMessage As BCToast
	
	Private bgndColor As Int
	Private borderColor As Int
	Private textColor As Int
	Private pnlBackground As B4XView
	
#if B4A
	Private rp As RuntimePermissions
#end if
	
	Private pbWait As B4XLoadingIndicator

	Public btnSave As Button
	Public Gnss1 As GNSS
	Public ConstellationToString As Map

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
	Starter.manager.Initialize("manager")
	ScanTimer.Initialize("ScanTimer", 10000)	' timeout for scans
	ConnectTimer.Initialize("ConnectTimer", 10000)	' timeout for connection
	ToastMessage.Initialize(Root)
	
	Page1.Initialize	'initializes Page1
	Page2.Initialize	'initializes Page2
	B4XPages.AddPage("Page 1", Page1)	'adds Page1 to the B4XPages list
	B4XPages.AddPage("Page 2", Page2)	'adds Page2 to the B4XPages list

	bgndColor = Starter.bgndColor
	borderColor = Starter.borderColor
	textColor = Starter.textColor
	
	' Put a save button in the action bar for Page 2. It will also be used for a Map button
	' in Page 1, but since there is only one action bar, it must do double duty.
	' This must be done here (and the clicks trapped here; see below)
	Dim p As B4XView = xui.CreatePanel("")
	p.SetLayoutAnimated(0, 0, 0, 150dip, 45dip)
	btnSave.Initialize("btnSave")
	btnSave.Text = "Save"
	btnSave.As(B4XView).SetColorAndBorder(bgndColor, 2dip, borderColor, 4dip)
	p.AddView(btnSave, 5dip, 0, p.Width - 10dip, p.Height)
	B4XPages.GetManager.ActionBar.RunMethod("setCustomView", Array(p))

	' Set up the Scan button.
	btnScanAndConnect.Text = "Scan for devices"
	btnScanAndConnect.SetColorAndBorder(bgndColor, 2dip, borderColor, 4dip)
	Dim b As Button = btnScanAndConnect
	b.TextColor = textColor
	pbWait.Hide
	Connected = False
	
	' Initialize GPS
	Gnss1.Initialize("Gnss1")
	Dim gs As GnssStatus 'ignore
	ConstellationToString = CreateMap(gs.CONSTELLATION_BEIDOU: "BEIDOU", gs.CONSTELLATION_GALILEO: "GALILEO", _
		gs.CONSTELLATION_GLONASS: "GLONASS", gs.CONSTELLATION_GPS: "GPS", gs.CONSTELLATION_QZSS: "QZSS", gs.CONSTELLATION_SBAS: "SBAS")

	' Start scanning right now, don't wait for the button
	btnScanAndConnect_Click
End Sub

'You can see the list of page related events in the B4XPagesManager object. The event name is B4XPage.
'Display Page1

Private Sub B4XPage_Appear
	pnlBackground.SetColorAndBorder(bgndColor, 0, borderColor, 0)
	If Connected Then
		' when coming back from Page1, disconnect any connected peripheral
		Starter.manager.Disconnect
		'Manager_Disconnected   ' it's already called
	End If
	B4XPages.GetManager.ActionBar.RunMethod("setDisplayOptions", Array(0, 16))  ' remove the save button
End Sub

Private Sub B4XPage_Disappear
	' Disable these timers if they are running, just to tidy up
	ScanTimer.Enabled = False
	ConnectTimer.Enabled = False
End Sub

' Scan for devices and populate the list view.
Private Sub btnScanAndConnect_Click
	
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
	clv.Clear

	' Add GPS bike at start of list. Color it like a device item.
	clv.AddTextItem("GPS Bike", "0")
	Dim p = clv.GetRawListItem(clv.Size - 1).Panel.GetView(0) As B4XView
	Dim t As B4XView = p.GetView(0)
	p.SetColorAndBorder(bgndColor, 4dip, 0x00000000, 0)
	t.TextColor = textColor

	pbWait.Show
	ScanTimer.Enabled = True
	Starter.manager.Scan2(Null, False)
	Return
	
End Sub

Sub Manager_DeviceFound (Name As String, Id As String, AdvertisingData As Map, RSSI As Double)
	' Dim bc As ByteConverter
	Log("Found: " & Name & ", " & Id & ", RSSI = " & RSSI & ", " & AdvertisingData) 'ignore
	
	'' What's in the advertising data?
	' Key 1, value 0x06
	' Key 2, value 0x18 18 0A 18 (18 18 is the CP service short UUID)
	' Key 9, value 'Babelfish67:5D' (the device name)
	For Each k As Int In AdvertisingData.Keys
		If k <> 0 Then
			Dim b() As Byte = AdvertisingData.Get(k)
			' Log("Key: " & k & ", Value ASCII: " & BytesToString(b, 0, b.Length, "utf8") & ", Value hex: " &  bc.HexFromBytes(b)  )
		End If
		If k == 2 Then
			' Check first two bytes of advertising data for the advertised service ID.
			' If it's not advertising CSC or CP then we don't offer it.
			Dim AdvertisedService As Int = Page1.Unsigned2(b(0), b(1))
			If AdvertisedService <> 0x1816 And AdvertisedService <> 0x1818 Then
				Return
			End If
		End If
	Next
	' Blank names get skipped too. (not sure where these come from)
	If Name.Length == 0 Then
		Return
	End If
		
	' Add item to list view
	clv.AddTextItem(Name, Id)

	' Some black magic to dig out the underlying Panel and TextView
	' from the list view item. Set the colours.
	Dim p = clv.GetRawListItem(clv.Size - 1).Panel.GetView(0) As B4XView
	Dim t As B4XView = p.GetView(0)
	p.SetColorAndBorder(bgndColor, 4dip, 0x00000000, 0)
	t.TextColor = textColor
	pbWait.Hide
	ScanTimer.Enabled = False
End Sub

' Timer routine fires when no devices are found within a reasonable time
Sub ScanTimer_Tick
	ToastMessage.Show("No devices found")
	ScanTimer.Enabled = False
	pbWait.Hide
	Starter.manager.StopScan
End Sub

Sub Manager_Disconnected
	Log("Disconnected")
	Connected = False
	Dim pws As PhoneWakeState
	pws.ReleaseKeepAlive
End Sub

' Device clicked on - connect to the device and throw us to Page1
Private Sub clv_ItemClick (Index As Int, Value As Object)
	Log("connecting to")
	Log(Value)
	ConnectedIndex = Index
	ConnectedId = Value.As(String)
	ConnectedName = clv.GetPanel(Index).GetView(0).Text
	If Index > 0 Then
		pbWait.Show
		ConnectTimer.Enabled = True
#if B4A
		Starter.manager.Connect2(ConnectedId, False) 'disabling auto connect can make the connection quicker
#else if B4I
		manager.Connect(ConnectedId)
#end if
	Else
		' This is the GPS bike. There's no BLE to connect to, so throw to Page 1 straight away.
		pbWait.Hide
		Starter.ConnectedServices.Initialize
		B4XPages.ShowPage("Page 1")
		'Can only set title after page is shown.
		B4XPages.SetTitle(Page1, ConnectedName)
		Dim pws As PhoneWakeState
		pws.KeepAlive(True)
	End If		
End Sub

Sub Manager_Connected (services As List)
	Log("Connected")
	Connected = True
	pbWait.Hide
	ConnectTimer.Enabled = False
	Starter.ConnectedServices = services
	' Throw to Page 1
	B4XPages.ShowPage("Page 1")
	'Can only set title after page is shown.
	B4XPages.SetTitle(Page1, ConnectedName)
	Dim pws As PhoneWakeState
	pws.KeepAlive(True)
End Sub

' Timer routine fires when the device could not connect within a reasonable time
' (e.g. it has gone away between discovery and user click)
Sub ConnectTimer_Tick
	ToastMessage.Show("Cannot connect to device")
	ConnectTimer.Enabled = False
	pbWait.Hide
	' Remove device from the list
	clv.RemoveAt(ConnectedIndex)
End Sub


' This is triggered by entering Page 1, but it has to be defined here. It that because
' the manager is initialised here? The mysteries of pages and scopes...
Sub Manager_DataAvailable(ServiceId As String, Characteristics As Map)
	Page1.AvailCallback(ServiceId, Characteristics)
End Sub

' Pass action bar button ("save" button) clicks to the right page, depending on what was
' showing when it was pressed.
Sub btnSave_Click
	Log(Sender.As(Button).Text & " pressed in " & B4XPages.GetManager.GetTopPage.Id) ' comes out as "page 1" or "page 2"
	Select B4XPages.GetManager.GetTopPage.Id.ToLowerCase		' just in case (haha)
		Case "page 2"
			' Pass clicks back to Page 2 when its Save button is pressed.
			Page2.SaveCallback

#if 0			
		Case "page 1"
			' Throw to Page 3
			B4XPages.ShowPage("Page 3")
			'Can only set title after page is shown.
			B4XPages.SetTitle(Page3, ConnectedName)
			Dim pws As PhoneWakeState
			pws.KeepAlive(True)
#end if
	End Select
End Sub

