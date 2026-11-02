#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "tray.h"
#include "win32_window.h"

// The Toolkit's window: the Flutter view, and its tray icon (T5). Started by Windows at sign-in
// (--tray) it stays hidden; with "Start with Windows" on, closing it hides it in the tray.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|; hidden when
  // |start_hidden| (started in the tray).
  FlutterWindow(const flutter::DartProject& project, bool start_hidden);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Shows the window and brings it to the front (from the tray)
  void ShowAndFocus();

  // "survey_toolkit/tray": start, keepInTray, notify, remove from Dart; checkNow to Dart
  void SetUpTrayChannel();

  std::unique_ptr<Tray> tray_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool start_hidden_;
  bool keep_in_tray_;
  bool told_about_tray_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
