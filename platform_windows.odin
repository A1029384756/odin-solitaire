package main

import "core:c"

foreign import glfw_ {
  "glfw3_mt.lib"
}

@(default_calling_convention="c", link_prefix="glfw")
foreign glfw_ {
  SwapInterval :: proc(val: c.int) ---
}

set_vsync :: proc(on: bool) {
  SwapInterval(i32(on))
}
