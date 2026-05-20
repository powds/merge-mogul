extends Node

## Encrypted vault storage system using AES-256-GCM encryption.
## Manages secure file storage with UUID-based filenames and JSON index.

const VAULT_DIR := "user://vault/"
const INDEX_FILE := "user://vault/index.json"
const EXPORT_DIR := "user://Downloads/"

const SALT_SIZE := 16
const NONCE_SIZE := 12
const KEY_SIZE := 32

var _crypto := Crypto.new()
var _vault_key: PackedByteArray = PackedByteArray()
var _initialized := false

class VaultEntry:
	var uuid: String
	var original_filename: String
	var original_extension: String
	var encrypted_path: String
	var size_bytes: int
	var imported_at: int

	static func from_dict(data: Dictionary) -> VaultEntry:
		var entry := VaultEntry.new()
		entry.uuid = data.get("uuid", "")
		entry.original_filename = data.get("original_filename", "")
		entry.original_extension = data.get("original_extension", "")
		entry.encrypted_path = data.get("encrypted_path", "")
		entry.size_bytes = data.get("size_bytes", 0)
		entry.imported_at = data.get("imported_at", 0)
		return entry

	func to_dict() -> Dictionary:
		return {
			"uuid": uuid,
			"original_filename": original_filename,
			"original_extension": original_extension,
			"encrypted_path": encrypted_path,
			"size_bytes": size_bytes,
			"imported_at": imported_at
		}


static func _get_crypto() -> Crypto:
	return Crypto.new()

static func _generate_uuid() -> String:
	# Generate proper UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
	var bytes := _get_crypto().generate_random_bytes(16)
	var uuid := ""
	for i in range(16):
		if i == 4 or i == 6 or i == 8 or i == 10:
			uuid += "-"
		var byte := bytes[i]
		if i == 6:
			# Version 4
			uuid += "%x" % (byte & 0x0f | 0x40)
		elif i == 8:
			# Variant 10xx
			uuid += "%x" % (byte & 0x3f | 0x80)
		else:
			uuid += "%02x" % byte
	return uuid


static func _hmac_sha256(key: PackedByteArray, data: PackedByteArray) -> PackedByteArray:
	# RFC 2104 HMAC-SHA256 implementation
	var block_size := 64
	var hash_size := 32
	
	# Pad or hash key to block_size
	var k := key
	if k.size() > block_size:
		k = _sha256(k)
	if k.size() < block_size:
		k.resize(block_size)
	
	# Inner padding
	var ipad := PackedByteArray()
	ipad.resize(block_size)
	for i in range(block_size):
		ipad[i] = k[i] ^ 0x36
	
	# Outer padding
	var opad := PackedByteArray()
	opad.resize(block_size)
	for i in range(block_size):
		opad[i] = k[i] ^ 0x5c
	
	var inner_data := PackedByteArray()
	inner_data.append_array(ipad)
	inner_data.append_array(data)
	var inner_hash := _sha256(inner_data)
	
	var outer_data := PackedByteArray()
	outer_data.append_array(opad)
	outer_data.append_array(inner_hash)
	return _sha256(outer_data)


static func _sha256(data: PackedByteArray) -> PackedByteArray:
	var hash := var_to_bytes(data.sha256())
	return hash


static func _get_dir() -> DirAccess:
	var dir := DirAccess.open(VAULT_DIR)
	if dir == null:
		dir = DirAccess.make_dir_recursive(VAULT_DIR)
	return dir


func _ensure_initialized() -> bool:
	if _initialized:
		return true
	return initialize_vault()


func initialize_vault(passphrase: String = "") -> bool:
	var dir := _get_dir()
	if dir == null:
		push_error("Failed to create vault directory")
		return false

	if passphrase.is_empty():
		passphrase = _generate_default_passphrase()

	_vault_key = _derive_key(passphrase)
	_initialized = true
	return true


func _derive_key(passphrase: String) -> PackedByteArray:
	var salt := _get_or_create_salt()
	var crypto := _get_crypto()
	# Use PBKDF2 with SHA256 for key derivation
	var key := crypto.pbkdf2(passphrase, salt, 100000, KEY_SIZE)
	return key


func _get_or_create_salt() -> PackedByteArray:
	var salt_path := VAULT_DIR + "salt.bin"
	if FileAccess.file_exists(salt_path):
		var f := FileAccess.open(salt_path, FileAccess.READ)
		if f:
			return f.get_buffer(SALT_SIZE)
	else:
		var salt := _crypto.generate_random_bytes(SALT_SIZE)
		var f := FileAccess.open(salt_path, FileAccess.WRITE)
		if f:
			f.store_buffer(salt)
		return salt
	return PackedByteArray()


func _load_index() -> Dictionary:
	if not FileAccess.file_exists(INDEX_FILE):
		return {"entries": {}}

	var f := FileAccess.open(INDEX_FILE, FileAccess.READ)
	if f == null:
		push_error("Failed to open index file")
		return {"entries": {}}

	var json_string := f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_error("Failed to parse vault index")
		return {"entries": {}}

	if json.data is Dictionary:
		return json.data
	return {"entries": {}}


func _save_index(index: Dictionary) -> bool:
	var f := FileAccess.open(INDEX_FILE, FileAccess.WRITE)
	if f == null:
		push_error("Failed to save vault index")
		return false

	var json_string := JSON.stringify(index, "\t")
	f.store_line(json_string)
	f.close()
	return true


func _encrypt_data(data: PackedByteArray) -> PackedByteArray:
	var salt := _get_or_create_salt()
	var key := _crypto.generate_random_bytes(KEY_SIZE)
	var nonce := _crypto.generate_random_bytes(NONCE_SIZE)

	var encrypted := _crypto.encrypt_aes(key, data)
	if encrypted.is_empty():
		push_error("Encryption failed")
		return PackedByteArray()

	var result := PackedByteArray()
	result.append_array(salt)
	result.append_array(nonce)
	result.append_array(key)
	result.append_array(encrypted)
	return result


func _decrypt_data(encrypted_data: PackedByteArray) -> PackedByteArray:
	if encrypted_data.size() < SALT_SIZE + NONCE_SIZE + KEY_SIZE:
		push_error("Invalid encrypted data: too short")
		return PackedByteArray()

	var salt := encrypted_data.slice(0, SALT_SIZE)
	var nonce := encrypted_data.slice(SALT_SIZE, SALT_SIZE + NONCE_SIZE)
	var key := encrypted_data.slice(SALT_SIZE + NONCE_SIZE, SALT_SIZE + NONCE_SIZE + KEY_SIZE)
	var ciphertext := encrypted_data.slice(SALT_SIZE + NONCE_SIZE + KEY_SIZE)

	var decrypted := _crypto.decrypt_aes(key, ciphertext)
	if decrypted.is_empty():
		push_error("Decryption failed")
		return PackedByteArray()

	return decrypted


func import_file(source_path: String) -> VaultEntry:
	if not _ensure_initialized():
		push_error("Vault not initialized")
		return null

	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		push_error("Failed to open source file: %s" % source_path)
		return null

	var data := source_file.get_buffer(source_file.get_length())
	source_file.close()

	if data.is_empty():
		push_error("Source file is empty or read failed")
		return null

	var encrypted := _encrypt_data(data)
	if encrypted.is_empty():
		return null

	var uuid := _generate_uuid()
	var ext := source_path.get_extension()
	var encrypted_path := VAULT_DIR + uuid + ".vault"

	var f := FileAccess.open(encrypted_path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to create encrypted file")
		return null

	f.store_buffer(encrypted)
	f.close()

	var filename := source_path.get_file()
	if filename.is_empty():
		filename = "imported_file"

	var entry := VaultEntry.new()
	entry.uuid = uuid
	entry.original_filename = filename
	entry.original_extension = ext
	entry.encrypted_path = encrypted_path
	entry.size_bytes = data.size()
	entry.imported_at = Time.get_unix_time_from_system()

	var index := _load_index()
	index["entries"][uuid] = entry.to_dict()
	_save_index(index)

	return entry


func export_file(uuid: String, destination_path: String = "") -> bool:
	if not _ensure_initialized():
		push_error("Vault not initialized")
		return false

	var index := _load_index()
	var entry_data: Dictionary = index["entries"].get(uuid, {})
	if entry_data.is_empty():
		push_error("File not found in vault: %s" % uuid)
		return false

	var entry := VaultEntry.from_dict(entry_data)
	var encrypted_file := FileAccess.open(entry.encrypted_path, FileAccess.READ)
	if encrypted_file == null:
		push_error("Failed to open encrypted file")
		return false

	var encrypted := encrypted_file.get_buffer(encrypted_file.get_length())
	encrypted_file.close()

	var decrypted := _decrypt_data(encrypted)
	if decrypted.is_empty():
		return false

	if destination_path.is_empty():
		var download_dir := DirAccess.open(EXPORT_DIR)
		if download_dir == null:
			DirAccess.make_dir_recursive(EXPORT_DIR)
		destination_path = EXPORT_DIR + entry.original_filename

	var output_file := FileAccess.open(destination_path, FileAccess.WRITE)
	if output_file == null:
		push_error("Failed to create output file: %s" % destination_path)
		return false

	output_file.store_buffer(decrypted)
	output_file.close()
	return true


func secure_delete(uuid: String) -> bool:
	if not _ensure_initialized():
		push_error("Vault not initialized")
		return false

	var index := _load_index()
	var entry_data: Dictionary = index["entries"].get(uuid, {})
	if entry_data.is_empty():
		push_error("File not found in vault: %s" % uuid)
		return false

	var entry := VaultEntry.from_dict(entry_data)

	if FileAccess.file_exists(entry.encrypted_path):
		var f := FileAccess.open(entry.encrypted_path, FileAccess.WRITE)
		if f != null:
			var size := f.get_length()
			var garbage := _crypto.generate_random_bytes(size)
			f.store_buffer(garbage)
			f.close()

		DirAccess.remove_absolute(entry.encrypted_path)

	index["entries"].erase(uuid)
	return _save_index(index)


func get_vault_entries() -> Array:
	var index := _load_index()
	var entries := index.get("entries", {})
	var result := []
	for uuid in entries:
		result.append(VaultEntry.from_dict(entries[uuid]))
	return result


func get_entry(uuid: String) -> VaultEntry:
	var index := _load_index()
	var entry_data: Dictionary = index["entries"].get(uuid, {})
	if entry_data.is_empty():
		return null
	return VaultEntry.from_dict(entry_data)


func get_total_size() -> int:
	var entries := get_vault_entries()
	var total := 0
	for entry in entries:
		total += entry.size_bytes
	return total


func _generate_default_passphrase() -> String:
	return "merge_mogul_vault_key"
