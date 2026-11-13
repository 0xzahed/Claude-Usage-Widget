#include <gdk/gdk.h>

#include "my_application.h"

int main(int argc, char** argv) {
  // Prefer X11 (through XWayland on Wayland sessions). Wayland gives apps no
  // way to stay above other windows or to restore their position, and both
  // are essential for a floating widget. Falls back to Wayland if X11 is
  // unavailable; GDK_BACKEND still overrides this.
  gdk_set_allowed_backends("x11,wayland,*");

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
