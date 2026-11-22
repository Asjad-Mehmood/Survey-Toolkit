#include "start_splash.h"

#include <dwmapi.h>

#include "resource.h"

#pragma comment(lib, "dwmapi.lib")

namespace {

constexpr wchar_t kClass[] = L"EXCELTOKML_START_SPLASH";
constexpr UINT_PTR kTimer = 1;
constexpr COLORREF kNavy = RGB(0x0A, 0x1A, 0x36);
constexpr COLORREF kTrack = RGB(0x17, 0x38, 0x6B);
constexpr COLORREF kBar = RGB(0x5B, 0x9B, 0xFF);
constexpr COLORREF kMuted = RGB(0xA9, 0xB8, 0xD3);

HWND g_splash = nullptr;
HICON g_icon = nullptr;
HFONT g_name_font = nullptr;
HFONT g_note_font = nullptr;
const wchar_t* g_name = L"";
int g_step = 0;
int g_dpi = 96;

int Px(int v) { return MulDiv(v, g_dpi, 96); }

void Paint(HWND hwnd) {
  PAINTSTRUCT ps;
  HDC dc = BeginPaint(hwnd, &ps);
  RECT rc;
  GetClientRect(hwnd, &rc);
  const int w = rc.right, h = rc.bottom;

  // drawn off screen first, so the moving bar doesn't flicker
  HDC mem = CreateCompatibleDC(dc);
  HBITMAP bmp = CreateCompatibleBitmap(dc, w, h);
  HGDIOBJ old_bmp = SelectObject(mem, bmp);

  HBRUSH bg = CreateSolidBrush(kNavy);
  FillRect(mem, &rc, bg);
  DeleteObject(bg);

  const int icon = Px(72);
  if (g_icon) DrawIconEx(mem, (w - icon) / 2, Px(44), g_icon, icon, icon, 0, nullptr, DI_NORMAL);

  SetBkMode(mem, TRANSPARENT);
  RECT name_rc{0, Px(132), w, Px(168)};
  HGDIOBJ old_font = SelectObject(mem, g_name_font);
  SetTextColor(mem, RGB(0xFF, 0xFF, 0xFF));
  DrawTextW(mem, g_name, -1, &name_rc, DT_CENTER | DT_SINGLELINE | DT_VCENTER);
  RECT note_rc{0, Px(170), w, Px(194)};
  SelectObject(mem, g_note_font);
  SetTextColor(mem, kMuted);
  DrawTextW(mem, L"Starting\x2026", -1, &note_rc, DT_CENTER | DT_SINGLELINE | DT_VCENTER);
  SelectObject(mem, old_font);

  // a bar that keeps moving while the program starts
  const int bar_w = Px(200), bar_h = Px(4);
  const int bar_x = (w - bar_w) / 2, bar_y = Px(214);
  RECT track{bar_x, bar_y, bar_x + bar_w, bar_y + bar_h};
  HBRUSH track_brush = CreateSolidBrush(kTrack);
  FillRect(mem, &track, track_brush);
  DeleteObject(track_brush);
  const int seg = bar_w / 3;
  const int travel = bar_w + seg;
  const int pos = (g_step * Px(4)) % travel - seg;
  RECT moving{bar_x + (pos < 0 ? 0 : pos), bar_y, bar_x + (pos + seg > bar_w ? bar_w : pos + seg),
              bar_y + bar_h};
  if (moving.right > moving.left) {
    HBRUSH bar_brush = CreateSolidBrush(kBar);
    FillRect(mem, &moving, bar_brush);
    DeleteObject(bar_brush);
  }

  BitBlt(dc, 0, 0, w, h, mem, 0, 0, SRCCOPY);
  SelectObject(mem, old_bmp);
  DeleteObject(bmp);
  DeleteDC(mem);
  EndPaint(hwnd, &ps);
}

LRESULT CALLBACK Proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
  switch (msg) {
    case WM_PAINT:
      Paint(hwnd);
      return 0;
    case WM_ERASEBKGND:
      return 1;
    case WM_TIMER:
      g_step++;
      InvalidateRect(hwnd, nullptr, FALSE);
      return 0;
  }
  return DefWindowProcW(hwnd, msg, wp, lp);
}

HFONT Font(int pt, int weight) {
  return CreateFontW(-MulDiv(pt, g_dpi, 72), 0, 0, 0, weight, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                     OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH,
                     L"Segoe UI");
}

}  // namespace

void ShowStartSplash(HINSTANCE instance, const wchar_t* name) {
  if (g_splash) return;
  g_name = name;
  HDC screen = GetDC(nullptr);
  g_dpi = GetDeviceCaps(screen, LOGPIXELSX);
  ReleaseDC(nullptr, screen);

  WNDCLASSW wc{};
  wc.lpfnWndProc = Proc;
  wc.hInstance = instance;
  wc.hCursor = LoadCursor(nullptr, IDC_APPSTARTING);
  wc.lpszClassName = kClass;
  RegisterClassW(&wc);

  g_icon = static_cast<HICON>(
      LoadImageW(instance, MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON, Px(72), Px(72), 0));
  g_name_font = Font(16, FW_SEMIBOLD);
  g_note_font = Font(10, FW_NORMAL);

  // in the middle of the screen the program opens on
  POINT cursor;
  GetCursorPos(&cursor);
  MONITORINFO mi{sizeof(mi)};
  GetMonitorInfoW(MonitorFromPoint(cursor, MONITOR_DEFAULTTOPRIMARY), &mi);
  const int w = Px(420), h = Px(260);
  const RECT& work = mi.rcWork;
  const int x = work.left + (work.right - work.left - w) / 2;
  const int y = work.top + (work.bottom - work.top - h) / 2;

  g_splash = CreateWindowExW(WS_EX_TOOLWINDOW, kClass, name, WS_POPUP, x, y, w, h, nullptr,
                             nullptr, instance, nullptr);
  if (!g_splash) return;
  // rounded corners on Windows 11 (DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)
  const DWORD corner = 2;
  DwmSetWindowAttribute(g_splash, 33, &corner, sizeof(corner));
  ShowWindow(g_splash, SW_SHOWNORMAL);
  UpdateWindow(g_splash);
  SetTimer(g_splash, kTimer, 16, nullptr);
}

void CloseStartSplash() {
  if (!g_splash) return;
  KillTimer(g_splash, kTimer);
  DestroyWindow(g_splash);
  g_splash = nullptr;
  if (g_icon) DestroyIcon(g_icon);
  if (g_name_font) DeleteObject(g_name_font);
  if (g_note_font) DeleteObject(g_note_font);
  g_icon = nullptr;
  g_name_font = g_note_font = nullptr;
}
