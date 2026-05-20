extends Node

const TARGET_REFRESH_RATE := 60
const MIN_AUTO_SOURCE_REFRESH_RATE := 120
const SCRIPT_PATH := "user://display_refresh_switch.ps1"
const RESTORE_STATE_PATH := "user://display_refresh_restore.cfg"

var _captured_refresh_rate := 0
var _captured_screen_index := -1
var _auto_switch_active := false
var _last_summary := "not_called"


func _ready() -> void:
	_load_restore_state()


func _exit_tree() -> void:
	restore_refresh_rate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		restore_refresh_rate()


func apply_auto_60hz(screen_index: int = DisplayServer.SCREEN_OF_MAIN_WINDOW) -> bool:
	if OS.get_name() != "Windows":
		_last_summary = "unsupported_os=%s" % OS.get_name()
		return false
	var current_rate := _get_screen_refresh_rate(screen_index)
	if current_rate < MIN_AUTO_SOURCE_REFRESH_RATE:
		_last_summary = "skip_current=%d_screen=%d" % [current_rate, screen_index]
		return false
	if _captured_refresh_rate <= 0:
		_captured_refresh_rate = current_rate
		_captured_screen_index = screen_index
		_save_restore_state(screen_index, current_rate)
	var result := _run_windows_refresh_tool("set", TARGET_REFRESH_RATE, screen_index)
	var succeeded := bool(result.get("ok", false))
	_auto_switch_active = succeeded
	_last_summary = "apply_ok=%s_screen=%d_from=%d_target=%d_exit=%d_output=%s" % [
		"on" if succeeded else "off",
		screen_index,
		current_rate,
		TARGET_REFRESH_RATE,
		int(result.get("exit_code", -999)),
		_sanitize_output(str(result.get("output", ""))),
	]
	return succeeded


func restore_refresh_rate() -> bool:
	if not _auto_switch_active or _captured_refresh_rate <= 0:
		return false
	var screen_index := _captured_screen_index
	var target_rate := _captured_refresh_rate
	_auto_switch_active = false
	_captured_refresh_rate = 0
	_captured_screen_index = -1
	var result := _run_windows_refresh_tool("set", target_rate, screen_index)
	var succeeded := bool(result.get("ok", false))
	if succeeded:
		_clear_restore_state()
	_last_summary = "restore_ok=%s_screen=%d_target=%d_exit=%d_output=%s" % [
		"on" if succeeded else "off",
		screen_index,
		target_rate,
		int(result.get("exit_code", -999)),
		_sanitize_output(str(result.get("output", ""))),
	]
	return succeeded


func get_last_summary() -> String:
	return _last_summary


func is_auto_switch_active() -> bool:
	return _auto_switch_active


func _get_screen_refresh_rate(screen_index: int) -> int:
	var refresh_rate := DisplayServer.screen_get_refresh_rate(screen_index)
	if refresh_rate <= 0.0:
		refresh_rate = 60.0
	return max(30, int(round(refresh_rate)))


func _run_windows_refresh_tool(action: String, target_rate: int, screen_index: int) -> Dictionary:
	var script_error := _ensure_windows_refresh_script()
	if script_error != OK:
		return {
			"ok": false,
			"exit_code": script_error,
			"output": "script_error=%d" % script_error,
		}
	var output: Array = []
	var script_path := ProjectSettings.globalize_path(SCRIPT_PATH)
	var args: Array[String] = [
		"-NoProfile",
		"-ExecutionPolicy",
		"Bypass",
		"-File",
		script_path,
		"-Action",
		action,
		"-Target",
		str(target_rate),
		"-ScreenIndex",
		str(max(0, screen_index)),
	]
	var exit_code := OS.execute("powershell.exe", args, output, true, false)
	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"output": "\n".join(output),
	}


func _ensure_windows_refresh_script() -> int:
	var file := FileAccess.open(SCRIPT_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(_get_windows_refresh_script())
	file.close()
	return OK


func _save_restore_state(screen_index: int, refresh_rate: int) -> void:
	var config := ConfigFile.new()
	config.set_value("display", "screen_index", screen_index)
	config.set_value("display", "refresh_rate", refresh_rate)
	config.save(RESTORE_STATE_PATH)


func _load_restore_state() -> void:
	var config := ConfigFile.new()
	if not FileAccess.file_exists(RESTORE_STATE_PATH):
		return
	if config.load(RESTORE_STATE_PATH) != OK:
		return
	var refresh_rate := int(config.get_value("display", "refresh_rate", 0))
	if refresh_rate <= 0:
		return
	var screen_index := int(config.get_value("display", "screen_index", DisplayServer.SCREEN_OF_MAIN_WINDOW))
	var current_rate := _get_screen_refresh_rate(screen_index)
	if current_rate == refresh_rate or current_rate != TARGET_REFRESH_RATE:
		_clear_restore_state()
		return
	_captured_screen_index = screen_index
	_captured_refresh_rate = refresh_rate
	_auto_switch_active = true
	_last_summary = "restore_state_loaded_screen=%d_target=%d" % [_captured_screen_index, _captured_refresh_rate]


func _clear_restore_state() -> void:
	if FileAccess.file_exists(RESTORE_STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RESTORE_STATE_PATH))


func _sanitize_output(output: String) -> String:
	return output.strip_edges().replace(" ", "_").replace("\n", "|").replace("\r", "")


func _get_windows_refresh_script() -> String:
	return """
param(
    [string]$Action = "get",
    [int]$Target = 60,
    [int]$ScreenIndex = 0
)

$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DisplayRefreshInterop {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DISPLAY_DEVICE {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceKey;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern int ChangeDisplaySettingsEx(string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd, int dwflags, IntPtr lParam);
}
"@

$DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 0x1
$ENUM_CURRENT_SETTINGS = -1
$DM_DISPLAYFREQUENCY = 0x400000
$CDS_TEST = 0x2

function Get-DisplayDeviceName([int]$Index) {
    $attachedIndex = 0
    for ($i = 0; $i -lt 16; $i++) {
        $device = New-Object DisplayRefreshInterop+DISPLAY_DEVICE
        $device.cb = [Runtime.InteropServices.Marshal]::SizeOf($device)
        if (-not [DisplayRefreshInterop]::EnumDisplayDevices($null, [uint32]$i, [ref]$device, 0)) {
            break
        }
        if (($device.StateFlags -band $DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) -eq 0) {
            continue
        }
        if ($attachedIndex -eq $Index) {
            return $device.DeviceName
        }
        $attachedIndex += 1
    }
    return $null
}

$deviceName = Get-DisplayDeviceName -Index ([Math]::Max(0, $ScreenIndex))
if ([string]::IsNullOrWhiteSpace($deviceName)) {
    Write-Output "status=error reason=no_device screen=$ScreenIndex"
    exit 20
}

$mode = New-Object DisplayRefreshInterop+DEVMODE
$mode.dmSize = [Runtime.InteropServices.Marshal]::SizeOf($mode)
if ([DisplayRefreshInterop]::EnumDisplaySettings($deviceName, $ENUM_CURRENT_SETTINGS, [ref]$mode) -eq 0) {
    Write-Output "status=error reason=no_current_mode screen=$ScreenIndex device=$deviceName"
    exit 21
}

$current = $mode.dmDisplayFrequency
if ($Action -eq "get") {
    Write-Output "status=ok action=get screen=$ScreenIndex device=$deviceName refresh=$current"
    exit 0
}

$mode.dmFields = $DM_DISPLAYFREQUENCY
$mode.dmDisplayFrequency = $Target
$testResult = [DisplayRefreshInterop]::ChangeDisplaySettingsEx($deviceName, [ref]$mode, [IntPtr]::Zero, $CDS_TEST, [IntPtr]::Zero)
if ($testResult -ne 0) {
    Write-Output "status=error action=test screen=$ScreenIndex device=$deviceName from=$current target=$Target result=$testResult"
    exit 30
}

$applyResult = [DisplayRefreshInterop]::ChangeDisplaySettingsEx($deviceName, [ref]$mode, [IntPtr]::Zero, 0, [IntPtr]::Zero)
if ($applyResult -ne 0) {
    Write-Output "status=error action=set screen=$ScreenIndex device=$deviceName from=$current target=$Target result=$applyResult"
    exit 31
}

Write-Output "status=ok action=set screen=$ScreenIndex device=$deviceName from=$current target=$Target result=$applyResult"
exit 0
"""
