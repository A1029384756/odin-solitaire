#+build !js
package main

import "core:encoding/cbor"
import "core:fmt"
import "core:mem"
import "core:os"

load_settings :: proc() {
	conf_bin, read_err := os.read_entire_file(get_config("solitodin.txt"), context.temp_allocator)
	if read_err != nil {
		fmt.println("could not find settings, loading defaults")
		settings = SETTINGS_DEFAULT
		return
	}

	d_err := cbor.unmarshal_from_string(string(conf_bin), &settings.persistent)
	if d_err != nil {
		fmt.println("could not read settings, loading defaults")
		settings = SETTINGS_DEFAULT
	}
}

get_config :: proc(
	subfolder: string,
	allocator: mem.Allocator = context.temp_allocator,
) -> string {
	dir, _ := os.user_config_dir(allocator)
	joined, _ := os.join_path({dir, subfolder}, allocator)
	return joined
}

write_config :: proc() {
	encoded, err := cbor.marshal(settings.persistent, cbor.ENCODE_FULLY_DETERMINISTIC)
	assert(err == nil)
	defer delete(encoded)

	write_err := os.write_entire_file(get_config("solitodin.txt"), encoded)
	if write_err != nil {
		fmt.println("could not open settings file:", get_config("solitodin.txt"))
		return
	}
}
