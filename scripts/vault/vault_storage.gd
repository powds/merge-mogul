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
	if _vault_key.is_empty():
		push_error("Vault key not initialized")
		return PackedByteArray()
	
	var crypto := _get_crypto()
	var salt := _get_or_create_salt()
	var nonce := crypto.generate_random_bytes(NONCE_SIZE)
	
	# Use AES-256-CBC with HMAC-SHA256 for authenticated encryption
	var key_hash := _sha256(_vault_key)
	var mac_key := key_hash.slice(0, 16)  # First 16 bytes for HMAC
	
	# Generate derived key for this file
	var derived_key := _hmac_sha256(mac_key, salt + nonce)
	derived_key = derived_key.slice(0, KEY_SIZE)  # 32 bytes for AES
	
	# Apply PKCS7 padding
	var padded := _pkcs7_pad(data, 16)
	
	# Encrypt with AES-CBC
	var encrypted := crypto.encrypt_aes(derived_key, padded)
	if encrypted.is_empty():
		push_error("Encryption failed")
		return PackedByteArray()
	
	# Create integrity MAC over salt + nonce + ciphertext
	var mac_data := PackedByteArray()
	mac_data.append_array(salt)
	mac_data.append_array(nonce)
	mac_data.append_array(encrypted)
	var mac := _hmac_sha256(mac_key, mac_data)
	
	# Format: salt (16) | nonce (12) | mac (32) | ciphertext
	var result := PackedByteArray()
	result.append_array(salt)
	result.append_array(nonce)
	result.append_array(mac)
	result.append_array(encrypted)
	return result


func _decrypt_data(encrypted_data: PackedByteArray) -> PackedByteArray:
	if encrypted_data.size() < SALT_SIZE + NONCE_SIZE + 32:
		push_error("Invalid encrypted data: too short")
		return PackedByteArray()
	
	var salt := encrypted_data.slice(0, SALT_SIZE)
	var nonce := encrypted_data.slice(SALT_SIZE, SALT_SIZE + NONCE_SIZE)
	var mac := encrypted_data.slice(SALT_SIZE + NONCE_SIZE, SALT_SIZE + NONCE_SIZE + 32)
	var ciphertext := encrypted_data.slice(SALT_SIZE + NONCE_SIZE + 32)
	
	var key_hash := _sha256(_vault_key)
	var mac_key := key_hash.slice(0, 16)
	
	# Verify integrity MAC
	var mac_data := PackedByteArray()
	mac_data.append_array(salt)
	mac_data.append_array(nonce)
	mac_data.append_array(ciphertext)
	var expected_mac := _hmac_sha256(mac_key, mac_data)
	
	if not _constant_time_compare(mac, expected_mac):
		push_error("MAC verification failed - data may be tampered")
		return PackedByteArray()
	
	# Generate derived key
	var derived_key := _hmac_sha256(mac_key, salt + nonce)
	derived_key = derived_key.slice(0, KEY_SIZE)
	
	var crypto := _get_crypto()
	var decrypted := crypto.decrypt_aes(derived_key, ciphertext)
	if decrypted.is_empty():
		push_error("Decryption failed")
		return PackedByteArray()
	
	# Remove PKCS7 padding
	return _pkcs7_unpad(decrypted)


static func _pkcs7_pad(data: PackedByteArray, block_size: int) -> PackedByteArray:
	var pad_len := block_size - (data.size() % block_size)
	var padded := PackedByteArray()
	padded.append_array(data)
	for i in range(pad_len):
		padded.append(pad_len)
	return padded


static func _pkcs7_unpad(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return data
	var pad_len := data[data.size() - 1]
	if pad_len < 1 or pad_len > 16 or pad_len > data.size():
		return data
	# Verify all padding bytes
	for i in range(pad_len):
		if data[data.size() - 1 - i] != pad_len:
			return data
	return data.slice(0, data.size() - pad_len)


static func _constant_time_compare(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	var result := 0
	for i in range(a.size()):
		result |= a[i] ^ b[i]
	return result == 0


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
			var garbage := _get_crypto().generate_random_bytes(size)
			f.store_buffer(garbage)
			f.close()

		DirAccess.remove_absolute(entry.encrypted_path)

	index["entries"].erase(uuid)
	return _save_index(index)


func verify_vault_integrity() -> Dictionary:
	# Verify integrity of all vault files
	var index := _load_index()
	var entries := index.get("entries", {})
	var results := {
		"total": 0,
		"valid": 0,
		"corrupted": 0,
		"missing": 0,
		"errors": []
	}
	
	for uuid in entries:
		results.total += 1
		var entry := VaultEntry.from_dict(entries[uuid])
		
		if not FileAccess.file_exists(entry.encrypted_path):
			results.missing += 1
			results.errors.append("%s: File missing" % uuid)
			continue
		
		var f := FileAccess.open(entry.encrypted_path, FileAccess.READ)
		if f == null:
			results.corrupted += 1
			results.errors.append("%s: Could not open file" % uuid)
			continue
		
		var encrypted := f.get_buffer(f.get_length())
		f.close()
		
		# Try to decrypt to verify integrity
		var decrypted := _decrypt_data(encrypted)
		if decrypted.is_empty():
			results.corrupted += 1
			results.errors.append("%s: Decryption failed" % uuid)
		else:
			results.valid += 1
	
	return results


func export_vault(export_path: String) -> bool:
	# Export entire vault as encrypted archive
	if not _ensure_initialized():
		push_error("Vault not initialized")
		return false
	
	var index := _load_index()
	var entries := index.get("entries", {})
	
	var vault_data := {
		"version": 1,
		"exported_at": Time.get_unix_time_from_system(),
		"entries": []
	}
	
	for uuid in entries:
		var entry := VaultEntry.from_dict(entries[uuid])
		var entry_info := entry.to_dict()
		
		# Read and re-encrypt the file with a new nonce
		if FileAccess.file_exists(entry.encrypted_path):
			var f := FileAccess.open(entry.encrypted_path, FileAccess.READ)
			if f != null:
				var encrypted := f.get_buffer(f.get_length())
				f.close()
				entry_info["encrypted_data"] = Array(encrypted)  # Convert to array for JSON
			else:
				push_error("Failed to read: %s" % entry.encrypted_path)
				return false
		
		vault_data.entries.append(entry_info)
	
	var json_string := JSON.stringify(vault_data, "\t")
	var f := FileAccess.open(export_path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to create export file")
		return false
	
	# Encrypt the JSON with vault key
	var json_bytes := json_string.to_utf8_buffer()
	var encrypted_export := _encrypt_data(json_bytes)
	if encrypted_export.is_empty():
		push_error("Failed to encrypt export")
		f.close()
		DirAccess.remove_absolute(export_path)
		return false
	
	f.store_buffer(encrypted_export)
	f.close()
	return true


func import_vault(import_path: String) -> bool:
	# Import vault from encrypted archive
	if not _ensure_initialized():
		push_error("Vault not initialized")
		return false
	
	var f := FileAccess.open(import_path, FileAccess.READ)
	if f == null:
		push_error("Failed to open import file")
		return false
	
	var encrypted := f.get_buffer(f.get_length())
	f.close()
	
	var decrypted := _decrypt_data(encrypted)
	if decrypted.is_empty():
		push_error("Failed to decrypt vault archive")
		return false
	
	var json_string := decrypted.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_error("Failed to parse vault archive")
		return false
	
	if json.data.version != 1:
		push_error("Unsupported vault archive version")
		return false
	
	var vault_data := json.data
	var index := _load_index()
	var imported := 0
	
	for entry_data in vault_data.entries:
		var uuid := entry_data.uuid
		
		# Skip if already exists
		if index["entries"].has(uuid):
			continue
		
		# Write encrypted file
		var enc_data := PackedByteArray(entry_data.encrypted_data)
		var dest_path := VAULT_DIR + uuid + ".vault"
		var out_f := FileAccess.open(dest_path, FileAccess.WRITE)
		if out_f == null:
			push_error("Failed to create: %s" % dest_path)
			continue
		
		out_f.store_buffer(enc_data)
		out_f.close()
		
		# Update entry with correct path
		entry_data.encrypted_path = dest_path
		index["entries"][uuid] = entry_data
		imported += 1
	
	return _save_index(index) and imported > 0


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
