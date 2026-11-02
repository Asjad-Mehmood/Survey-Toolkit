#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <wchar.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Started by Windows at sign-in ("Start with Windows"): only the tray icon, no window
  const bool in_tray = command_line != nullptr && ::wcsstr(command_line, L"--tray") != nullptr;

  // One window at a time: opening the program again brings the open window to the front, also
  // when it is hidden in the tray.
  ::CreateMutexW(nullptr, TRUE, L"ExcelToKML.SurveyToolkit.SingleInstance");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND open = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Survey Toolkit");
    if (open != nullptr && !in_tray) {
      if (::IsIconic(open)) {
        ::ShowWindow(open, SW_RESTORE);
      } else if (!::IsWindowVisible(open)) {
        ::ShowWindow(open, SW_SHOW);
      }
      ::SetForegroundWindow(open);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, in_tray);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1180, 780);
  if (!window.Create(L"Survey Toolkit", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
