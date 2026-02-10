#+build linux
#+private
package term

import "core:os"
import "core:sys/linux"

@(private = "file")
Winsize :: struct {
	ws_row:    u16,
	ws_col:    u16,
	ws_xpixel: u16,
	ws_ypixel: u16,
}

_terminal_width :: proc() -> (int, bool) {
	ws: Winsize
	linux.ioctl(linux.Fd(os.stdout), linux.TIOCGWINSZ, uintptr(&ws))
	if ws.ws_col == 0 {
		return 0, false
	}
	return int(ws.ws_col), true
}
