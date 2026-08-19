#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <propkey.h>
#include <propvarutil.h>
#include <shellapi.h>
#include <shlobj.h>
#include <wincrypt.h>
#include <winrt/Windows.Data.Xml.Dom.h>
#include <winrt/Windows.UI.Notifications.h>
#include <winrt/base.h>

#include <fstream>
#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"
#include "utils.h"

namespace {
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kTrayOpen = 41001;
constexpr UINT kTrayExit = 41002;
constexpr wchar_t kStartupKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kStartupName[] = L"PersonalWorkbench";
constexpr wchar_t kAppUserModelId[] = L"PersonalWorkbench.Desktop";
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

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
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "personal_workbench/windows_activity",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "isAvailable") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "foregroundProcess") {
          result->Success(flutter::EncodableValue(ForegroundProcessName()));
        } else if (call.method_name() == "setCloseToTray") {
          close_to_tray_ = std::get<bool>(*call.arguments());
          result->Success();
        } else if (call.method_name() == "showWindow") {
          result->Success(flutter::EncodableValue(ShowWorkbench()));
        } else if (call.method_name() == "exitApplication") {
          exiting_ = true;
          result->Success();
          PostMessage(GetHandle(), WM_CLOSE, 0, 0);
        } else if (call.method_name() == "setStartupEnabled") {
          SetStartupEnabled(std::get<bool>(*call.arguments()));
          result->Success(flutter::EncodableValue(IsStartupEnabled()));
        } else if (call.method_name() == "startupEnabled") {
          result->Success(flutter::EncodableValue(IsStartupEnabled()));
        } else if (call.method_name() == "showNotification") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("invalid_arguments", "Notification data is missing");
            return;
          }
          const auto title = arguments->find(flutter::EncodableValue("title"));
          const auto body = arguments->find(flutter::EncodableValue("body"));
          if (title == arguments->end() || body == arguments->end()) {
            result->Error("invalid_arguments", "Notification title or body is missing");
            return;
          }
          ShowNotification(std::get<std::string>(title->second),
                           std::get<std::string>(body->second));
          result->Success();
        } else if (call.method_name() == "protectFile") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          const auto source = arguments->find(flutter::EncodableValue("sourcePath"));
          const auto destination = arguments->find(flutter::EncodableValue("destinationPath"));
          if (source == arguments->end() || destination == arguments->end()) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          result->Success(flutter::EncodableValue(ProtectFile(
              std::get<std::string>(source->second),
              std::get<std::string>(destination->second))));
        } else if (call.method_name() == "unprotectFile") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          const auto source = arguments->find(flutter::EncodableValue("sourcePath"));
          const auto destination = arguments->find(flutter::EncodableValue("destinationPath"));
          if (source == arguments->end() || destination == arguments->end()) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          result->Success(flutter::EncodableValue(UnprotectFile(
              std::get<std::string>(source->second),
              std::get<std::string>(destination->second))));
        } else {
          result->NotImplemented();
        }
      });
  AddTrayIcon();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();
  channel_.reset();
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

  switch (message) {
    case WM_POWERBROADCAST:
      if (channel_ && wparam == PBT_APMSUSPEND) {
        channel_->InvokeMethod(
            "powerEvent",
            std::make_unique<flutter::EncodableValue>("suspend"));
      } else if (channel_ &&
                 (wparam == PBT_APMRESUMEAUTOMATIC ||
                  wparam == PBT_APMRESUMESUSPEND)) {
        channel_->InvokeMethod(
            "powerEvent",
            std::make_unique<flutter::EncodableValue>("resume"));
      }
      return TRUE;
    case WM_CLOSE:
      if (close_to_tray_ && !exiting_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
    case WM_COMMAND:
      if (LOWORD(wparam) == kTrayOpen) {
        ShowWorkbench();
        return 0;
      }
      if (LOWORD(wparam) == kTrayExit) {
        exiting_ = true;
        RemoveTrayIcon();
        DestroyWindow(hwnd);
        return 0;
      }
      break;
    case kTrayMessage:
      if (lparam == WM_LBUTTONUP) {
        ShowWorkbench();
        return 0;
      }
      if (lparam == WM_RBUTTONUP) {
        ShowTrayMenu();
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::AddTrayIcon() {
  NOTIFYICONDATA data{};
  data.cbSize = sizeof(data);
  data.hWnd = GetHandle();
  data.uID = 1;
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  data.uCallbackMessage = kTrayMessage;
  data.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(data.szTip, L"\u4e2a\u4eba\u5de5\u4f5c\u53f0");
  Shell_NotifyIcon(NIM_ADD, &data);
}

void FlutterWindow::RemoveTrayIcon() {
  if (!GetHandle()) return;
  NOTIFYICONDATA data{};
  data.cbSize = sizeof(data);
  data.hWnd = GetHandle();
  data.uID = 1;
  Shell_NotifyIcon(NIM_DELETE, &data);
}

void FlutterWindow::ShowTrayMenu() {
  POINT point{};
  GetCursorPos(&point);
  HMENU menu = CreatePopupMenu();
  AppendMenu(menu, MF_STRING, kTrayOpen, L"\u6253\u5f00\u5de5\u4f5c\u53f0");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, kTrayExit, L"\u9000\u51fa");
  SetForegroundWindow(GetHandle());
  TrackPopupMenu(menu, TPM_RIGHTBUTTON, point.x, point.y, 0, GetHandle(), nullptr);
  DestroyMenu(menu);
}

bool FlutterWindow::ShowWorkbench() {
  ShowWindow(GetHandle(), SW_SHOW);
  ShowWindow(GetHandle(), SW_RESTORE);
  if (SetForegroundWindow(GetHandle())) return true;
  FLASHWINFO flash{};
  flash.cbSize = sizeof(flash);
  flash.hwnd = GetHandle();
  flash.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
  flash.uCount = 3;
  flash.dwTimeout = 0;
  FlashWindowEx(&flash);
  return false;
}

void FlutterWindow::ShowNotification(const std::string& title,
                                     const std::string& body) {
  if (ShowToastNotification(title, body)) return;
  if (!GetHandle()) return;
  const auto wide_title = Utf16FromUtf8(title);
  const auto wide_body = Utf16FromUtf8(body);
  NOTIFYICONDATA data{};
  data.cbSize = sizeof(data);
  data.hWnd = GetHandle();
  data.uID = 1;
  data.uFlags = NIF_INFO;
  data.dwInfoFlags = NIIF_INFO | NIIF_LARGE_ICON;
  wcsncpy_s(data.szInfoTitle, wide_title.c_str(), _TRUNCATE);
  wcsncpy_s(data.szInfo, wide_body.c_str(), _TRUNCATE);
  Shell_NotifyIcon(NIM_MODIFY, &data);
}

bool FlutterWindow::EnsureToastShortcut() const {
  PWSTR programs_path = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_Programs, KF_FLAG_DEFAULT, nullptr,
                                  &programs_path))) {
    return false;
  }
  const std::wstring shortcut_path =
      std::wstring(programs_path) + L"\\\u4e2a\u4eba\u5de5\u4f5c\u53f0.lnk";
  CoTaskMemFree(programs_path);
  std::vector<wchar_t> executable(32768);
  const DWORD length = GetModuleFileName(
      nullptr, executable.data(), static_cast<DWORD>(executable.size()));
  if (length == 0 || length >= executable.size()) return false;
  try {
    winrt::com_ptr<IShellLinkW> shell_link;
    winrt::check_hresult(CoCreateInstance(
        CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(shell_link.put())));
    winrt::check_hresult(shell_link->SetPath(executable.data()));
    winrt::check_hresult(shell_link->SetIconLocation(executable.data(), 0));

    const auto property_store = shell_link.as<IPropertyStore>();
    PROPVARIANT app_id{};
    winrt::check_hresult(InitPropVariantFromString(kAppUserModelId, &app_id));
    const HRESULT set_result =
        property_store->SetValue(PKEY_AppUserModel_ID, app_id);
    PropVariantClear(&app_id);
    winrt::check_hresult(set_result);
    winrt::check_hresult(property_store->Commit());

    const auto persist_file = shell_link.as<IPersistFile>();
    winrt::check_hresult(persist_file->Save(shortcut_path.c_str(), TRUE));
    return true;
  } catch (...) {
    return false;
  }
}

bool FlutterWindow::ShowToastNotification(const std::string& title,
                                          const std::string& body) const {
  if (!EnsureToastShortcut()) return false;
  try {
    using namespace winrt::Windows::Data::Xml::Dom;
    using namespace winrt::Windows::UI::Notifications;
    const XmlDocument content = ToastNotificationManager::GetTemplateContent(
        ToastTemplateType::ToastText02);
    const auto text_nodes = content.GetElementsByTagName(L"text");
    text_nodes.Item(0).AppendChild(
        content.CreateTextNode(winrt::to_hstring(title)));
    text_nodes.Item(1).AppendChild(
        content.CreateTextNode(winrt::to_hstring(body)));
    const ToastNotification toast(content);
    ToastNotificationManager::CreateToastNotifier(kAppUserModelId).Show(toast);
    return true;
  } catch (...) {
    return false;
  }
}

bool FlutterWindow::ProtectFile(const std::string& source_path,
                                const std::string& destination_path) const {
  std::ifstream input(Utf16FromUtf8(source_path), std::ios::binary | std::ios::ate);
  if (!input) return false;
  const auto size = input.tellg();
  if (size <= 0) return false;
  std::vector<BYTE> clear(static_cast<size_t>(size));
  input.seekg(0, std::ios::beg);
  if (!input.read(reinterpret_cast<char*>(clear.data()), size)) return false;

  DATA_BLOB clear_blob{};
  clear_blob.pbData = clear.data();
  clear_blob.cbData = static_cast<DWORD>(clear.size());
  DATA_BLOB encrypted_blob{};
  if (!CryptProtectData(&clear_blob, L"Personal Workbench migration backup",
                        nullptr, nullptr, nullptr,
                        CRYPTPROTECT_UI_FORBIDDEN, &encrypted_blob)) {
    return false;
  }
  std::ofstream output(Utf16FromUtf8(destination_path),
                       std::ios::binary | std::ios::trunc);
  const bool written = output && output.write(
      reinterpret_cast<const char*>(encrypted_blob.pbData),
      encrypted_blob.cbData).good();
  LocalFree(encrypted_blob.pbData);
  return written;
}

bool FlutterWindow::UnprotectFile(const std::string& source_path,
                                  const std::string& destination_path) const {
  std::ifstream input(Utf16FromUtf8(source_path), std::ios::binary | std::ios::ate);
  if (!input) return false;
  const auto size = input.tellg();
  if (size <= 0) return false;
  std::vector<BYTE> encrypted(static_cast<size_t>(size));
  input.seekg(0, std::ios::beg);
  if (!input.read(reinterpret_cast<char*>(encrypted.data()), size)) return false;

  DATA_BLOB encrypted_blob{};
  encrypted_blob.pbData = encrypted.data();
  encrypted_blob.cbData = static_cast<DWORD>(encrypted.size());
  DATA_BLOB clear_blob{};
  if (!CryptUnprotectData(&encrypted_blob, nullptr, nullptr, nullptr, nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN, &clear_blob)) {
    return false;
  }
  std::ofstream output(Utf16FromUtf8(destination_path),
                       std::ios::binary | std::ios::trunc);
  const bool written = output && output.write(
      reinterpret_cast<const char*>(clear_blob.pbData),
      clear_blob.cbData).good();
  LocalFree(clear_blob.pbData);
  return written;
}

std::string FlutterWindow::ForegroundProcessName() const {
  HWND foreground = GetForegroundWindow();
  if (!foreground) return {};
  DWORD process_id = 0;
  GetWindowThreadProcessId(foreground, &process_id);
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (!process) return {};
  std::vector<wchar_t> path(32768);
  DWORD length = static_cast<DWORD>(path.size());
  std::string result;
  if (QueryFullProcessImageName(process, 0, path.data(), &length)) {
    std::wstring full(path.data(), length);
    const auto separator = full.find_last_of(L"\\/");
    const std::wstring name = separator == std::wstring::npos
                                  ? full
                                  : full.substr(separator + 1);
    result = Utf8FromUtf16(name.c_str());
  }
  CloseHandle(process);
  return result;
}

void FlutterWindow::SetStartupEnabled(bool enabled) {
  HKEY key = nullptr;
  if (RegOpenKeyEx(HKEY_CURRENT_USER, kStartupKey, 0, KEY_SET_VALUE, &key) != ERROR_SUCCESS) return;
  if (enabled) {
    std::vector<wchar_t> path(32768);
    const DWORD length = GetModuleFileName(nullptr, path.data(), static_cast<DWORD>(path.size()));
    const std::wstring quoted = L"\"" + std::wstring(path.data(), length) + L"\"";
    RegSetValueEx(key, kStartupName, 0, REG_SZ,
                  reinterpret_cast<const BYTE*>(quoted.c_str()),
                  static_cast<DWORD>((quoted.size() + 1) * sizeof(wchar_t)));
  } else {
    RegDeleteValue(key, kStartupName);
  }
  RegCloseKey(key);
}

bool FlutterWindow::IsStartupEnabled() const {
  HKEY key = nullptr;
  if (RegOpenKeyEx(HKEY_CURRENT_USER, kStartupKey, 0, KEY_QUERY_VALUE, &key) != ERROR_SUCCESS) return false;
  const LONG status = RegQueryValueEx(key, kStartupName, nullptr, nullptr, nullptr, nullptr);
  RegCloseKey(key);
  return status == ERROR_SUCCESS;
}
