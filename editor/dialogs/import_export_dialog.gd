@tool
extends Window
class_name ImportExportDlg
## JSON-импорт/экспорт для всей базы или отдельных таблиц.

var _database: DBDatabase = null
var _text_edit: TextEdit
var _table_opt: OptionButton
var _format_opt: OptionButton
var _status_label: Label

func _ready() -> void:
	title = "Import / Export"
	min_size = Vector2i(640, 520)
	close_requested.connect(hide)
	_build_ui()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var opt_row := HBoxContainer.new()
	vbox.add_child(opt_row)

	opt_row.add_child(_lbl("Table:"))
	_table_opt = OptionButton.new()
	_table_opt.custom_minimum_size.x = 180
	opt_row.add_child(_table_opt)

	opt_row.add_child(_lbl("  Format:"))
	_format_opt = OptionButton.new()
	_format_opt.add_item("JSON (full)")
	_format_opt.add_item("CSV (current table)")
	opt_row.add_child(_format_opt)

	var btn_row := HBoxContainer.new()
	vbox.add_child(btn_row)
	var export_btn := Button.new(); export_btn.text = "▶ Export to Text"
	export_btn.pressed.connect(_on_export)
	btn_row.add_child(export_btn)
	var copy_btn := Button.new(); copy_btn.text = "⎘ Copy to Clipboard"
	copy_btn.pressed.connect(func(): DisplayServer.clipboard_set(_text_edit.text))
	btn_row.add_child(copy_btn)
	var save_btn := Button.new(); save_btn.text = "💾 Save to File…"
	save_btn.pressed.connect(_on_save_file)
	btn_row.add_child(save_btn)
	var load_btn := Button.new(); load_btn.text = "📂 Load from File…"
	load_btn.pressed.connect(_on_load_file)
	btn_row.add_child(load_btn)
	var import_btn := Button.new(); import_btn.text = "◀ Import from Text"
	import_btn.pressed.connect(_on_import)
	btn_row.add_child(import_btn)

	_text_edit = TextEdit.new()
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_edit.custom_minimum_size.y = 300
	vbox.add_child(_text_edit)

	_status_label = Label.new()
	_status_label.text = ""
	vbox.add_child(_status_label)

func open(db: DBDatabase) -> void:
	_database = db
	_table_opt.clear()
	_table_opt.add_item("(All tables)")
	for tname: String in db.get_table_names():
		_table_opt.add_item(tname)
	_text_edit.text = ""
	_status_label.text = ""
	popup_centered()

# ── Экспорт ───────────────────────────────────────────────────────────────────

func _on_export() -> void:
	if _database == null: return
	var fmt: int = _format_opt.selected
	var sel: int = _table_opt.selected

	if fmt == 0:   # JSON full
		var d: Dictionary
		if sel == 0:
			d = _database.to_json_dict()
		else:
			var tname: String = _table_opt.get_item_text(sel)
			d = _export_table_json(tname)
		_text_edit.text = JSON.stringify(d, "  ")
	else:          # CSV current table
		if sel == 0:
			_status_label.text = "Select a specific table for CSV export."
			return
		var tname: String = _table_opt.get_item_text(sel)
		_text_edit.text = _export_table_csv(tname)

	_status_label.text = "Exported. Copy or save to file."

func _export_table_json(tname: String) -> Dictionary:
	var t := _database.get_table(tname)
	if t == null: return {}
	var rows: Array = []
	for e: DBEntry in t.entries:
		rows.append(e.to_plain_dict())
	return { "table": tname, "schema": t.schema.schema_name if t.schema else "", "entries": rows }

func _export_table_csv(tname: String) -> String:
	var t := _database.get_table(tname)
	if t == null or t.schema == null: return ""
	var lines: PackedStringArray = PackedStringArray()
	var headers := PackedStringArray(["_id"])
	for f: DBFieldDef in t.schema.fields:
		headers.append(f.field_name)
	lines.append(_csv_row(headers))
	for e: DBEntry in t.entries:
		var row := PackedStringArray([e.entry_id])
		for f: DBFieldDef in t.schema.fields:
			row.append(_csv_cell(e.get_value(f.field_name)))
		lines.append(_csv_row(row))
	return "\n".join(lines)

func _csv_row(cols: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c in cols:
		if c.contains(",") or c.contains("\"") or c.contains("\n"):
			parts.append("\"" + c.replace("\"", "\"\"") + "\"")
		else:
			parts.append(c)
	return ",".join(parts)

func _csv_cell(v: Variant) -> String:
	if v == null: return ""
	if v is Color: return (v as Color).to_html(false)
	if v is Vector2: return "(%.4f,%.4f)" % [(v as Vector2).x, (v as Vector2).y]
	if v is Vector3: return "(%.4f,%.4f,%.4f)" % [(v as Vector3).x, (v as Vector3).y, (v as Vector3).z]
	if v is Array:   return "[%d items]" % (v as Array).size()
	return str(v)

# ── Импорт ────────────────────────────────────────────────────────────────────

func _on_import() -> void:
	if _database == null: return
	var raw := _text_edit.text.strip_edges()
	if raw.is_empty(): return

	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		_status_label.text = "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		return

	var data: Variant = json.get_data()
	if not (data is Dictionary):
		_status_label.text = "Expected a JSON object at root."
		return
	var d: Dictionary = data as Dictionary

	# Формат экспорта одной таблицы
	if d.has("entries") and d.has("table"):
		_import_table_json(d)
	# Экспорт всей базы
	elif d.has("tables"):
		for tname: String in d["tables"]:
			_import_table_json(d["tables"][tname], tname)
	else:
		_status_label.text = "Unrecognised JSON format."
		return
	_status_label.text = "Import complete."

func _import_table_json(td: Dictionary, override_name: String = "") -> void:
	var tname: String = override_name if not override_name.is_empty() else str(td.get("table", "imported"))
	var t := _database.get_table(tname)
	if t == null: return
	var entries: Array = td.get("entries", [])
	for row in entries:
		if not (row is Dictionary): continue
		var existing := t.get_entry(str(row.get("_id", "")))
		if existing:
			for key: String in row:
				if not key.begins_with("_"):
					existing.data[key] = row[key]
		else:
			var e := DBEntry.from_plain_dict(row)
			if e.entry_id.is_empty():
				e.entry_id = t._new_id()
			t.entries.append(e)
	t.emit_changed()

# ── Файловый ввод/вывод ───────────────────────────────────────────────────────

func _on_save_file() -> void:
	var dlg := EditorFileDialog.new()
	dlg.access   = EditorFileDialog.ACCESS_FILESYSTEM
	dlg.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dlg.add_filter("*.json", "JSON")
	dlg.add_filter("*.csv", "CSV")
	add_child(dlg)
	dlg.popup_centered(Vector2i(800, 550))
	dlg.file_selected.connect(func(path: String) -> void:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(_text_edit.text)
			f.close()
			_status_label.text = "Saved to %s" % path
		dlg.queue_free()
	)

func _on_load_file() -> void:
	var dlg := EditorFileDialog.new()
	dlg.access    = EditorFileDialog.ACCESS_FILESYSTEM
	dlg.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dlg.add_filter("*.json", "JSON")
	dlg.add_filter("*.csv", "CSV")
	add_child(dlg)
	dlg.popup_centered(Vector2i(800, 550))
	dlg.file_selected.connect(func(path: String) -> void:
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			_text_edit.text = f.get_as_text()
			f.close()
		dlg.queue_free()
	)

func _lbl(t: String) -> Label:
	var l := Label.new(); l.text = t; return l
