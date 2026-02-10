#+build darwin
#+private
package term

import "core:c"
import "core:os"
import "core:sys/darwin"

@(private="file")
Winsize :: struct {
  ws_row:    c.ushort,
  ws_col:    c.ushort,
  ws_xpixel: c.ushort,
  ws_ypixel: c.ushort,
}

_terminal_width :: proc() -> (int, bool) {
  ws: Winsize
  ret := darwin.syscall_ioctl(c.int(os.stdout), darwin.TIOCGWINSZ, &ws)
  if ret < 0 || ws.ws_col == 0 {
    return 0, false
  }
  return int(ws.ws_col), true
}
