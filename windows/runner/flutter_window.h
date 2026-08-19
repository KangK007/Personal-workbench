#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void AddTrayIcon();
  void RemoveTrayIcon();
  void ShowTrayMenu();
  bool ShowWorkbench();
  void ShowNotification(const std::string& title, const std::string& body);
  bool ShowToastNotification(const std::string& title,
                             const std::string& body) const;
  bool EnsureToastShortcut() const;
  bool ProtectFile(const std::string& source_path,
                   const std::string& destination_path) const;
  bool UnprotectFile(const std::string& source_path,
                     const std::string& destination_path) const;
  void SetStartupEnabled(bool enabled);
  bool IsStartupEnabled() const;
  std::string ForegroundProcessName() const;

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool close_to_tray_ = true;
  bool exit_guard_ = false;
  bool exiting_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
