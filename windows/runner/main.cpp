#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shobjidl_core.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "restriction_hosts.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // The elevated hosts helper is launched from the running desktop process
  // with this same executable. Dispatch it before taking the desktop mutex;
  // otherwise the helper sees the UI instance and returns success without
  // touching the hosts file.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const int worker_result = RunRestrictionHostsWorker(command_line_arguments);
  if (worker_result >= 0) {
    ::CoUninitialize();
    return worker_result;
  }

  // The desktop app is single-instance. A repeated shortcut click should
  // focus the existing window instead of starting another Flutter runtime.
  HANDLE instance_mutex = ::CreateMutexW(
      nullptr, TRUE, L"Local\\PersonalWorkbench.Desktop.SingleInstance");
  if (instance_mutex == nullptr) {
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(instance_mutex);
    HWND existing = ::FindWindowW(nullptr, L"\u4E2A\u4EBA\u5DE5\u4F5C\u53F0");
    if (existing != nullptr) {
      if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
    }
    return EXIT_SUCCESS;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // COM was initialized before worker dispatch, so it is available for the
  // Flutter library and plugins as well.
  ::SetCurrentProcessExplicitAppUserModelID(L"PersonalWorkbench.Desktop");

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"\u4E2A\u4EBA\u5DE5\u4F5C\u53F0", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::ReleaseMutex(instance_mutex);
  ::CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
