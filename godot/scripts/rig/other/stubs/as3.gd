class_name AS3
extends RefCounted
## Flash `int(v)` for OTHER's rig runtime: truncated toward zero, wrapped to 32 bits;
## NaN, ±inf, null and non-numbers give 0.


static func i32(v: Variant) -> int:
	var f := 0.0
	match typeof(v):
		TYPE_INT:
			f = float(v)
		TYPE_BOOL:
			return 1 if v else 0
		TYPE_FLOAT:
			f = v
		TYPE_STRING, TYPE_STRING_NAME:
			f = String(v).to_float()
		_:
			return 0
	if is_nan(f) or is_inf(f):
		return 0
	var n := int(f) & 0xFFFFFFFF
	return n - 0x100000000 if n >= 0x80000000 else n
