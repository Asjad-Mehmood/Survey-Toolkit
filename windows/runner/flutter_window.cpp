#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project, bool start_hidden)
    : project_(project), start_hidden_(start_hidden), keep_in_tray_(start_hidden) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  tray_ = std::make_unique<Tray>(GetHandle());
  SetUpTrayChannel();

  // started by Windows at sign-in: only the tray icon, no window
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (!start_hidden_) this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  channel_ = nullptr;
  tray_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  if (tray_) {
    switch (tray_->Handle(message, lparam)) {
      case Tray::kOpen:
        ShowAndFocus();
        return 0;
      case Tray::kCheck:
        if (channel_) channel_->InvokeMethod("checkNow", nullptr);
        return 0;
      case Tray::kQuit:
        keep_in_tray_ = false;
        ::DestroyWindow(hwnd);
        return 0;
      case Tray::kNone:
        break;
    }
    if (message == Tray::kMessage) return 0;
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_CLOSE:
      // "Start with Windows" is on: the Toolkit goes on in the tray, keeping the tools up to date
      if (keep_in_tray_ && tray_) {
        ::ShowWindow(hwnd, SW_HIDE);
        tray_->Add();
        if (!told_about_tray_) {
          told_about_tray_ = true;
          tray_->Notify(L"Survey Toolkit is still running",
                        L"It keeps your tools up to date in the background. Open it from this icon, or right-click "
                        L"it and choose Quit.");
        }
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::ShowAndFocus() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) return;
  ::ShowWindow(hwnd, ::IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(hwnd);
}

void FlutterWindow::SetUpTrayChannel() {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "survey_toolkit/tray",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method = call.method_name();
        if (!tray_) {
          result->Success();
          return;
        }
        if (method == "start") {
          tray_->Add();
          result->Success();
        } else if (method == "keepInTray") {
          const auto* on = std::get_if<bool>(call.arguments());
          keep_in_tray_ = on != nullptr && *on;
          result->Success();
        } else if (method == "notify") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          auto text = [args](const char* key) -> std::wstring {
            if (args == nullptr) return std::wstring();
            auto found = args->find(flutter::EncodableValue(std::string(key)));
            if (found == args->end()) return std::wstring();
            const auto* value = std::get_if<std::string>(&found->second);
            return value == nullptr ? std::wstring() : WideFromUtf8(*value);
          };
          tray_->Notify(text("title"), text("text"));
          result->Success();
        } else if (method == "remove") {
          tray_->Remove();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}
