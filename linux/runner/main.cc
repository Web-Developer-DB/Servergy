#include "my_application.h"

// Linux desktop entry point generated around the custom MyApplication shell.
// It creates the GTK application once and hands its lifecycle to GLib.
int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
