package cli_style

import "core:fmt"
import "core:log"

OnError :: enum { Ignore, Warn, Error }

Options :: struct {
  parsing: OnError,
}

package_options := &Options{
  parsing = OnError.Warn,
}

// set_options sets the package-level formatting options.
//
// Parameters:
//   opts: The Options struct containing the desired formatting settings.
set_options :: proc(opts: ^Options) {
  package_options = opts
}

// init_formatter initializes the formatting system with optional settings.
// Enables use of println and other default-format printers. Needs to be called before Styled_Text objects can be
// printed with proper formatting.
@(private="file")
@(init)
init_formatter :: proc() {
  fmt.set_user_formatters(new(map[typeid]fmt.User_Formatter))

  // Register the custom formatter for Styled_Text
  err := fmt.register_user_formatter(type_info_of(Styled_Text).id, Styled_Text_Formatter)
}
