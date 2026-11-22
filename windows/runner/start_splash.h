#ifndef RUNNER_START_SPLASH_H_
#define RUNNER_START_SPLASH_H_

#include <windows.h>

// The start screen: a small window with the program's icon and name, shown the moment the
// program is opened and closed when its main window shows its first frame, so opening it is
// never a wait with nothing on screen.
void ShowStartSplash(HINSTANCE instance, const wchar_t* name);
void CloseStartSplash();

#endif  // RUNNER_START_SPLASH_H_
