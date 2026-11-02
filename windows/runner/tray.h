#ifndef RUNNER_TRAY_H_
#define RUNNER_TRAY_H_

#include <windows.h>

#include <string>

// The Survey Toolkit's icon in the notification area (T5): click it to open the window, right-click
// for Open, Check for updates now and Quit. Its notifications ("Slope Calculator updated to 1.0.3")
// are shown by Windows 10 and 11 as ordinary notifications.
class Tray {
 public:
  // The icon's messages to the window
  static constexpr UINT kMessage = WM_APP + 41;

  // What the user asked for
  enum Command : UINT { kNone = 0, kOpen = 1, kCheck = 2, kQuit = 3 };

  explicit Tray(HWND window);
  ~Tray();

  Tray(const Tray&) = delete;
  Tray& operator=(const Tray&) = delete;

  void Add();
  void Remove();
  void Notify(const std::wstring& title, const std::wstring& text);

  // A message to the window: the icon's, or Explorer starting again (the icon is put back)
  Command Handle(UINT message, LPARAM lparam);

 private:
  Command ShowMenu();

  HWND window_;
  UINT taskbar_created_;
  HICON icon_ = nullptr;
  HICON big_icon_ = nullptr;
  bool added_ = false;
};

// UTF-8 (from Dart) to the UTF-16 Windows uses
std::wstring WideFromUtf8(const std::string& text);

#endif  // RUNNER_TRAY_H_
