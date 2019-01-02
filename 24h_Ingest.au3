#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Icons\record.ico
#AutoIt3Wrapper_Res_Comment=Überwacht den 24h-Ingest-Ordner. Keine wachsenden Files zeigen rot an.
#AutoIt3Wrapper_Res_Description=Überwacht den 24h-Ingest-Ordner. Keine wachsenden Files zeigen rot an.
#AutoIt3Wrapper_Res_Fileversion=1.0.0.9
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_LegalCopyright=Conrad Zelck
#AutoIt3Wrapper_Res_Language=1031
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <File.au3>
#include <Date.au3>
#include <TrayCox.au3> ; source: https://github.com/SimpelMe/TrayCox

Global Const $g_sRegKey = "HKEY_CURRENT_USER\Software\" & @ScriptName ; path to registry

Global $hShowWarnung = TrayCreateItem("Zeige Warnung", -1, 0)
TrayItemSetOnEvent (-1, "ShowWarnung")
Global $hResetWarnung = TrayCreateItem("Reset Warnung", -1, 1)
TrayItemSetOnEvent (-1, "ResetWarnung")
TrayCreateItem("", -1, 2)
Global $hIni = TrayCreateItem("Pfad setzen", -1, 3)
TrayItemSetOnEvent (-1, "Pfad")
Global $hPauseSetzen = TrayCreateItem("Pause setzen", -1, 4)
TrayItemSetOnEvent (-1, "Pause")
TrayCreateItem("", -1, 5)

; look for the path or set it
Global $sPfad = RegRead($g_sRegKey, "Pfad")
ConsoleWrite("Pfad: " & $sPfad & "\" & @CRLF)
While Not FileExists($sPfad)
	$sPfad = Pfad()
WEnd

; look for a pause time or set it
Global $iPause = RegRead($g_sRegKey, "Pause")
ConsoleWrite("Pause: " & $iPause & "s" & @CRLF)
While Not $iPause
	$iPause = Pause()
WEnd

Local $sMsg
Local $aScanOrdner
Local $iStart
Local $aTemp[1][2]
Local $aDateAndSize[0][2]
Local $sCurrentFile
Local $iTempSize
Local $iCurrentFileSize
Global $g_bUnterbrechung = False
Global $g_bUnterbrechungLabel = False
Global $g_sMessageWarnung

Local $hParent = WinGetHandle(AutoItWinGetTitle()) ; so no taskbar is to see
Global $hGUI = GUICreate("24h_Ingest", 300, 300, -1, -1, $WS_SIZEBOX + $WS_POPUP + $WS_BORDER, $WS_EX_TOPMOST, $hParent)
Local $hDragLabel = GUICtrlCreateLabel("", 0, 0, 300, 300, -1, $GUI_WS_EX_PARENTDRAG) ; lays on top and is for drag and move the gui
Global $g_hWarnungLabel = GUICtrlCreateLabel("", 0, 150, 300, 150)
GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
GUICtrlCreateLabel("24h_INGEST", 0, 0, 300, 300, $SS_CENTER)
GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
GUICtrlSetFont(-1, 14)
GUISetBkColor(0xFF0000, $hGUI)
GUISetState(@SW_SHOW)

While 1
	$sMsg = GUIGetMsg()
	Switch $sMsg
		Case $GUI_EVENT_CLOSE
			ExitLoop
	EndSwitch
	$aScanOrdner = _FileListToArrayRec($sPfad, "*", 1, 1, 0, 2)
	$iStart = TimerInit()
	ReDim $aTemp[1][2]
	ReDim $aDateAndSize[0][2]
	For $i = 1 To UBound($aScanOrdner) -1
		$aTemp[0][0] = $aScanOrdner[$i]
		$aTemp[0][1] = FileGetTime($aScanOrdner[$i], 0, 1) ; date modified
		_ArrayAdd($aDateAndSize, $aTemp)
	Next
	_ArraySort($aDateAndSize, 1, 0, 0, 1) ; newest date first
	ConsoleWrite("ScanTime alle Datum ermitteln: " & Round(TimerDiff($iStart)) & "ms" & @CRLF)
	If UBound($aDateAndSize) > 0 Then
		$sCurrentFile = $aDateAndSize[0][0]
	Else
		$sCurrentFile = 0
	EndIf
	ConsoleWrite("Neuestes File: " & $sCurrentFile & @CRLF)
	$iTempSize = FileGetSize($sCurrentFile)
	If $iCurrentFileSize = $iTempSize Then
		GUISetBkColor(0xFF0000, $hGUI)
		If $g_bUnterbrechung = False Then
			If $g_sMessageWarnung Then
				$g_sMessageWarnung &= @CRLF
			EndIf
			$g_sMessageWarnung &= _NowDate() & " " & _NowTime()
		EndIf
		$g_bUnterbrechung = True
		$g_bUnterbrechungLabel = True
		GUICtrlSetBkColor($g_hWarnungLabel, 0xFFFF00)
	Else
		GUISetBkColor(0x00FF00, $hGUI)
		If $g_bUnterbrechung = True Then
			$g_sMessageWarnung &= " - " & _NowDate() & " " & _NowTime()
			$g_bUnterbrechung = False
		EndIf
		$iCurrentFileSize = $iTempSize
	EndIf
	Sleep($iPause * 1000)
WEnd
Exit

Func Pfad()
	Local $sFolder = FileSelectFolder("" & Chr(0xDC) & "berwachungsordner aussuchen", StringLeft(RegRead($g_sRegKey, "Pfad"), StringInStr(RegRead($g_sRegKey, "Pfad"), "\", 0, - 1)))
	If @error Then Return
	ConsoleWrite("Pfad: " & $sFolder & "\" & @CRLF)
	RegWrite($g_sRegKey, "Pfad", "REG_SZ", $sFolder)
	$sPfad = $sFolder
	Return $sFolder
EndFunc

Func Pause()
	Local $bSetPause = 0
	While Not $bSetPause
		$iPause = InputBox("Pausen-Timer", "Bitte die Zeit in Sekunden angeben, die das Tool nach jedem Scan pausieren soll:", RegRead($g_sRegKey, "Pause"))
		$bSetPause = StringRegExp($iPause, "[1-9][0-9]*?")
	WEnd
	RegWrite($g_sRegKey, "Pause", "REG_DWORD", $iPause)
	Return $iPause
EndFunc

Func ShowWarnung()
	If $g_sMessageWarnung Then
		MsgBox(262144, 'Unterbrechungen', $g_sMessageWarnung)
	Else
		MsgBox(262144, 'Unterbrechungen', "Keine Unterbrechungen seit dem letzten Start/Reset festgestellt.")
	EndIf
EndFunc

Func ResetWarnung()
	Local $iOK = MsgBox(262148, 'Unterbrechungen', "M" & Chr(0xF6) & "chtest Du die Warnung wirklich zur" & Chr(0xFC) & "cksetzen?")
	If $iOK = 6 Then
		$g_bUnterbrechung = False
		$g_bUnterbrechungLabel = False
		$g_sMessageWarnung = ""
		GUICtrlSetBkColor($g_hWarnungLabel, $GUI_BKCOLOR_TRANSPARENT)
	EndIf
EndFunc