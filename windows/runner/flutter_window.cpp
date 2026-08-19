#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <propkey.h>
#include <propvarutil.h>
#include <shellapi.h>
#include <shlobj.h>
#include <tlhelp32.h>
#include <wincrypt.h>
#include <winrt/Windows.Data.Xml.Dom.h>
#include <winrt/Windows.UI.Notifications.h>
#include <winrt/base.h>

#include <algorithm>
#include <cctype>
#include <fstream>
#include <map>
#include <optional>
#include <set>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "restriction_hosts.h"
#include "resource.h"
#include "utils.h"

namespace {
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kTrayOpen = 41001;
constexpr UINT kTrayExit = 41002;
constexpr wchar_t kStartupKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kStartupName[] = L"PersonalWorkbench";
constexpr wchar_t kAppUserModelId[] = L"PersonalWorkbench.Desktop";

std::wstring Lowercase(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(), towlower);
  return value;
}

std::wstring BaseName(const std::wstring& path) {
  const auto separator = path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? path : path.substr(separator + 1);
}

bool IsSystemProcess(const std::wstring& name, const std::wstring& path) {
  static const std::set<std::wstring> names = {
      L"system",          L"system idle process", L"registry",
      L"wininit.exe",     L"winlogon.exe",        L"services.exe",
      L"lsass.exe",       L"csrss.exe",           L"smss.exe",
      L"svchost.exe",     L"dwm.exe",             L"explorer.exe",
      L"taskhostw.exe",   L"sihost.exe",          L"runtimebroker.exe",
      L"searchhost.exe",  L"textinputhost.exe",   L"msmpeng.exe",
      L"personal_workbench.exe"};
  const auto lower_name = Lowercase(name);
  if (names.find(lower_name) != names.end()) return true;
  const auto lower_path = Lowercase(path);
  return lower_path.rfind(L"c:\\windows\\", 0) == 0 ||
         lower_path.find(L"\\windows\\") != std::wstring::npos;
}

BOOL CALLBACK CollectWindowTitle(HWND window, LPARAM parameter) {
  if (!IsWindowVisible(window)) return TRUE;
  DWORD process_id = 0;
  GetWindowThreadProcessId(window, &process_id);
  if (process_id == 0) return TRUE;
  const int length = GetWindowTextLengthW(window);
  if (length <= 0 || length > 32767) return TRUE;
  std::vector<wchar_t> title(static_cast<size_t>(length) + 1);
  if (GetWindowTextW(window, title.data(), length + 1) <= 0) return TRUE;
  auto* titles = reinterpret_cast<std::map<DWORD, std::vector<std::string>>*>(
      parameter);
  (*titles)[process_id].push_back(Utf8FromUtf16(title.data()));
  return TRUE;
}

flutter::EncodableList ProcessSnapshot() {
  std::map<DWORD, std::vector<std::string>> window_titles;
  EnumWindows(CollectWindowTitle, reinterpret_cast<LPARAM>(&window_titles));
  flutter::EncodableList values;
  const HANDLE snapshot =
      CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return values;
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  if (Process32FirstW(snapshot, &entry)) {
    do {
      if (entry.th32ProcessID == 0 ||
          entry.th32ProcessID == GetCurrentProcessId()) {
        continue;
      }
      std::wstring path;
      const HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,
                                         FALSE, entry.th32ProcessID);
      if (process) {
        std::vector<wchar_t> buffer(32768);
        DWORD length = static_cast<DWORD>(buffer.size());
        if (QueryFullProcessImageNameW(process, 0, buffer.data(), &length)) {
          path.assign(buffer.data(), length);
        }
        CloseHandle(process);
      }
      if (IsSystemProcess(entry.szExeFile, path)) continue;
      flutter::EncodableList titles;
      const auto found = window_titles.find(entry.th32ProcessID);
      if (found != window_titles.end()) {
        for (const auto& title : found->second) {
          titles.emplace_back(title);
        }
      }
      flutter::EncodableMap item;
      item[flutter::EncodableValue("pid")] = flutter::EncodableValue(
          static_cast<int64_t>(entry.th32ProcessID));
      item[flutter::EncodableValue("name")] =
          flutter::EncodableValue(Utf8FromUtf16(entry.szExeFile));
      item[flutter::EncodableValue("executablePath")] =
          flutter::EncodableValue(Utf8FromUtf16(path.c_str()));
      item[flutter::EncodableValue("windowTitles")] =
          flutter::EncodableValue(titles);
      values.emplace_back(item);
    } while (Process32NextW(snapshot, &entry));
  }
  CloseHandle(snapshot);
  return values;
}

bool TerminateExpectedProcess(int64_t process_id,
                              const std::string& expected_name) {
  if (process_id <= 0 || process_id > MAXDWORD ||
      static_cast<DWORD>(process_id) == GetCurrentProcessId()) {
    return false;
  }
  const HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION |
                                         PROCESS_TERMINATE,
                                     FALSE, static_cast<DWORD>(process_id));
  if (!process) return false;
  std::vector<wchar_t> path(32768);
  DWORD length = static_cast<DWORD>(path.size());
  const bool queried =
      QueryFullProcessImageNameW(process, 0, path.data(), &length) == TRUE;
  const std::wstring actual = queried
                                  ? Lowercase(BaseName(
                                        std::wstring(path.data(), length)))
                                  : std::wstring();
  const bool matches =
      queried && actual == Lowercase(Utf16FromUtf8(expected_name));
  const bool protected_process = queried && IsSystemProcess(actual, path.data());
  const bool terminated =
      matches && !protected_process && TerminateProcess(process, 1) == TRUE;
  CloseHandle(process);
  return terminated;
}

std::vector<std::string> StringListArgument(
    const flutter::EncodableMap& arguments, const std::string& key) {
  const auto found = arguments.find(flutter::EncodableValue(key));
  if (found == arguments.end()) return {};
  const auto* values = std::get_if<flutter::EncodableList>(&found->second);
  if (!values) return {};
  std::vector<std::string> result;
  for (const auto& value : *values) {
    if (const auto* text = std::get_if<std::string>(&value)) {
      result.push_back(*text);
    }
  }
  return result;
}

flutter::EncodableValue HostsStatusValue(
    const RestrictionHostsStatus& status) {
  flutter::EncodableList missing;
  for (const auto& entry : status.missing_entries) missing.emplace_back(entry);
  flutter::EncodableMap value;
  value[flutter::EncodableValue("supported")] =
      flutter::EncodableValue(status.supported);
  value[flutter::EncodableValue("administrator")] =
      flutter::EncodableValue(status.administrator);
  value[flutter::EncodableValue("active")] =
      flutter::EncodableValue(status.active);
  value[flutter::EncodableValue("markerPresent")] =
      flutter::EncodableValue(status.marker_present);
  value[flutter::EncodableValue("externallyModified")] =
      flutter::EncodableValue(status.externally_modified);
  value[flutter::EncodableValue("missingEntries")] =
      flutter::EncodableValue(missing);
  value[flutter::EncodableValue("error")] =
      flutter::EncodableValue(status.error);
  return flutter::EncodableValue(value);
}
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
        } else if (call.method_name() == "processSnapshot") {
          result->Success(flutter::EncodableValue(ProcessSnapshot()));
        } else if (call.method_name() == "terminateProcess") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          const auto pid = arguments->find(flutter::EncodableValue("pid"));
          const auto name =
              arguments->find(flutter::EncodableValue("expectedName"));
          if (pid == arguments->end() || name == arguments->end()) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          const auto* process_id = std::get_if<int64_t>(&pid->second);
          const auto* expected_name = std::get_if<std::string>(&name->second);
          result->Success(flutter::EncodableValue(
              process_id && expected_name &&
              TerminateExpectedProcess(*process_id, *expected_name)));
        } else if (call.method_name() == "hostsStatus") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          result->Success(HostsStatusValue(GetRestrictionHostsStatus(
              arguments ? StringListArgument(*arguments, "domains")
                        : std::vector<std::string>())));
        } else if (call.method_name() == "applyHostsPolicy") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          result->Success(flutter::EncodableValue(
              arguments && ApplyRestrictionHostsPolicy(
                               StringListArgument(*arguments, "domains"))));
        } else if (call.method_name() == "clearHostsPolicy") {
          result->Success(
              flutter::EncodableValue(ClearRestrictionHostsPolicy()));
        } else if (call.method_name() == "isAdministrator") {
          result->Success(flutter::EncodableValue(IsProcessAdministrator()));
        } else if (call.method_name() == "setExitGuard") {
          exit_guard_ = std::get<bool>(*call.arguments());
          result->Success();
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
      if (exit_guard_ && !exiting_) {
        ShowWorkbench();
        ShowNotification("\u81ea\u5f8b\u4fdd\u62a4\u6b63\u5728\u8fd0\u884c",
                         "\u8bf7\u5728\u81ea\u5f8b\u9875\u9a8c\u8bc1\u540e\u9000\u51fa\u5e94\u7528\u3002");
        if (channel_) {
          channel_->InvokeMethod(
              "exitRequested", std::make_unique<flutter::EncodableValue>());
        }
        return 0;
      }
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
        if (exit_guard_) {
          ShowWorkbench();
          ShowNotification("\u81ea\u5f8b\u4fdd\u62a4\u6b63\u5728\u8fd0\u884c",
                           "\u8bf7\u5728\u81ea\u5f8b\u9875\u9a8c\u8bc1\u540e\u9000\u51fa\u5e94\u7528\u3002");
          if (channel_) {
            channel_->InvokeMethod(
                "exitRequested", std::make_unique<flutter::EncodableValue>());
          }
          return 0;
        }
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
