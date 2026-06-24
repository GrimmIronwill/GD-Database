@tool
class_name DBSchema
extends Resource

@export var schema_name: String = "Schema"
@export var description: String = ""
@export var fields: Array[DBFieldDef] = []

# ──────────────────────────────────────────────────────────────────────────────

func get_field(name: String) -> DBFieldDef:
	for f: DBFieldDef in fields:
		if f.field_name == name:
			return f
	return null

func has_field(name: String) -> bool:
	return get_field(name) != null

func add_field(field: DBFieldDef) -> bool:
	if has_field(field.field_name):
		return false
	fields.append(field)
	emit_changed()
	return true

func remove_field(name: String) -> bool:
	for i: int in range(fields.size()):
		if fields[i].field_name == name:
			fields.remove_at(i)
			emit_changed()
			return true
	return false

func move_field(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= fields.size(): return
	if to_idx < 0 or to_idx >= fields.size(): return
	var f: DBFieldDef = fields[from_idx]
	fields.remove_at(from_idx)
	fields.insert(to_idx, f)
	emit_changed()

func get_field_names() -> PackedStringArray:
	var out := PackedStringArray()
	for f: DBFieldDef in fields:
		out.append(f.field_name)
	return out

## Build a fresh data Dictionary with all default values.
func make_default_data() -> Dictionary:
	var d: Dictionary = {}
	for f: DBFieldDef in fields:
		d[f.field_name] = f.get_default()
	return d

## Ensure an existing data dict has all schema keys; add missing, keep extra.
func normalize_data(data: Dictionary) -> Dictionary:
	for f: DBFieldDef in fields:
		if not data.has(f.field_name):
			data[f.field_name] = f.get_default()
	return data
