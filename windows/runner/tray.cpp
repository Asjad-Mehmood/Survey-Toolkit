#include "tray.h"

#include <shellapi.h>

#include "resource.h"

namespace {

constexpr UINT kIconId = 1;

NOTIFYICONDATAW DataFor(HWND window, UINT flags) {
  NOTIFYICONDATAW d = {};
  d.cbSize = sizeof(d);
  d.hWnd = window;
  d.uID = kIconId;
  d.uFlags = flags;
  return d;
}

HICON LoadAppIcon(int width, int height) {
  return static_cast<HICON>(::LoadImageW(::GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON),
                                         IMAGE_ICON, width, height, LR_DEFAULTCOLOR));
}

}  // namespace

std::wstring WideFromUtf8(const std::string& text) {
  if (text.empty()) return std::wstring();
  const int length = ::MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
  if (length <= 0) return std::wstring();
  std::wstring wide(static_cast<size_t>(length), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), wide.data(), length);
  return wide;
}

Tray::Tray(HWND window) : window_(window) {
  taskbar_created_ = ::RegisterWindowMessageW(L"TaskbarCreated");
  icon_ = LoadAppIcon(::GetSystemMetrics(SM_CXSMICON), ::GetSystemMetrics(SM_CYSMICON));
  big_icon_ = LoadAppIcon(::GetSystemMetrics(SM_CXICON), ::GetSystemMetrics(SM_CYICON));
}

Tray::~Tray() {
  Remove();
  if (icon_ != nullptr) ::DestroyIcon(icon_);
  if (big_icon_ != nullptr) ::DestroyIcon(big_icon_);
}

void Tray::Add() {
  if (added_) return;
  NOTIFYICONDATAW d = DataFor(window_, NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP);
  d.uCallbackMessage = kMessage;
  d.hIcon = icon_;
  wcscpy_s(d.szTip, L"Survey Toolkit");
  if (!::Shell_NotifyIconW(NIM_ADD, &d)) return;
  d.uVersion = NOTIFYICON_VERSION_4;
  ::Shell_NotifyIconW(NIM_SETVERSION, &d);
  added_ = true;
}

void Tray::Remove() {
  if (!added_) return;
  NOTIFYICONDATAW d = DataFor(window_, 0);
  ::Shell_NotifyIconW(NIM_DELETE, &d);
  added_ = false;
}

void Tray::Notify(const std::wstring& title, const std::wstring& text) {
  Add();
  if (!added_) return;
  NOTIFYICONDATAW d = DataFor(window_, NIF_INFO);
  wcsncpy_s(d.szInfoTitle, title.c_str(), _TRUNCATE);
  wcsncpy_s(d.szInfo, text.c_str(), _TRUNCATE);
  d.dwInfoFlags = NIIF_USER | NIIF_LARGE_ICON;
  d.hBalloonIcon = big_icon_;
  ::Shell_NotifyIconW(NIM_MODIFY, &d);
}

Tray::Command Tray::Handle(UINT message, LPARAM lparam) {
  if (message == taskbar_created_) {
    // Explorer started again: the icon has to be added again, if it was there
    if (added_) {
      added_ = false;
      Add();
    }
    return kNone;
  }
  if (message != kMessage) return kNone;
  switch (LOWORD(lparam)) {
    case NIN_SELECT:
    case NIN_KEYSELECT:
    case NIN_BALLOONUSERCLICK:
      return kOpen;
    case WM_CONTEXTMENU:
      return ShowMenu();
  }
  return kNone;
}

Tray::Command Tray::ShowMenu() {
  HMENU menu = ::CreatePopupMenu();
  if (menu == nullptr) return kNone;
  ::AppendMenuW(menu, MF_STRING, kOpen, L"Open Survey Toolkit");
  ::AppendMenuW(menu, MF_STRING, kCheck, L"Check for updates now");
  ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  ::AppendMenuW(menu, MF_STRING, kQuit, L"Quit");
  ::SetMenuDefaultItem(menu, kOpen, FALSE);
  POINT at = {};
  ::GetCursorPos(&at);
  // so the menu closes when the user clicks elsewhere
  ::SetForegroundWindow(window_);
  const UINT chosen = static_cast<UINT>(
      ::TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_NONOTIFY, at.x, at.y, 0, window_, nullptr));
  ::PostMessageW(window_, WM_NULL, 0, 0);
  ::DestroyMenu(menu);
  switch (chosen) {
    case kOpen:
      return kOpen;
    case kCheck:
      return kCheck;
    case kQuit:
      return kQuit;
  }
  return kNone;
}
