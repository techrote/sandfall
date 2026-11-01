class_name SandfallBrowserFileBridge
extends RefCounted

# Bounded browser packaging only. The chooser returns bytes to Godot's staged
# validator; it has no application/session setter and cannot execute archives.
signal selected(bytes: PackedByteArray, filename: String, serial: int)
signal refused(reason: String, serial: int)
signal cancelled(serial: int)

const ArchiveZip = preload("res://scripts/sandfall/archive_zip.gd")
const MAX_ARCHIVE_BYTES: int = ArchiveZip.MAX_ARCHIVE_BYTES
var _callback: JavaScriptObject
var _serial: int = 0
var _active: bool = false


func open_project() -> int:
	_serial += 1
	_active = true
	if not OS.has_feature("web"):
		return _serial
	if _callback == null:
		_callback = JavaScriptBridge.create_callback(_receive)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.sandfallFileCallback = _callback
	JavaScriptBridge.eval("""
(() => {
  const serial = %d;
  const old = document.getElementById('sandfall-project-file');
  if (old) old.remove();
  const input = document.createElement('input');
  input.type = 'file'; input.accept = '.sandfall,.zip,application/zip';
  input.id = 'sandfall-project-file'; input.hidden = true;
  document.body.appendChild(input);
  let finished = false;
  function done(status, name, data) {
    if (finished) return; finished = true;
    window.sandfallFileCallback(status, name, data, serial);
    input.remove();
  }
  input.addEventListener('cancel', () => done('cancel', '', null), {once:true});
  input.addEventListener('change', async () => {
    const file = input.files && input.files[0];
    if (!file) { done('cancel', '', null); return; }
    if (file.size > %d) { done('archive_file_too_large', file.name, null); return; }
    try { done('ok', file.name, await file.arrayBuffer()); }
    catch (_) { done('archive_file_read_failed', file.name, null); }
  }, {once:true});
  input.click();
})()
""" % [_serial, MAX_ARCHIVE_BYTES], true)
	return _serial


func cancel() -> void:
	_active = false
	_serial += 1
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(() => { const e=document.getElementById('sandfall-project-file'); if(e)e.remove(); })()", true)


func _receive(arguments: Array) -> void:
	if arguments.size() != 4 or not _active or int(arguments[3]) != _serial:
		return
	_active = false
	var status: String = str(arguments[0])
	if status == "cancel":
		cancelled.emit(_serial)
	elif status != "ok":
		refused.emit(status, _serial)
	elif not arguments[2] is JavaScriptObject or not JavaScriptBridge.is_js_buffer(arguments[2]):
		refused.emit("archive_file_buffer_invalid", _serial)
	else:
		var bytes: PackedByteArray = JavaScriptBridge.js_buffer_to_packed_byte_array(arguments[2])
		if bytes.size() > MAX_ARCHIVE_BYTES:
			refused.emit("archive_file_too_large", _serial)
		else:
			selected.emit(bytes, str(arguments[1]).get_file(), _serial)


static func offer_download(bytes: PackedByteArray, filename: String, mime: String) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_ARCHIVE_BYTES or filename.is_empty() or filename != filename.get_file():
		return {"accepted": false, "error": "invalid_download"}
	if not OS.has_feature("web"):
		return {"accepted": false, "error": "desktop_save_dialog_required"}
	JavaScriptBridge.download_buffer(bytes, filename, mime)
	return {"accepted": true, "delivery": "browser_download_requested", "bytes": bytes.size()}
