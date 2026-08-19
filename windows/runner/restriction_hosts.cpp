#include "restriction_hosts.h"

#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>

#include <algorithm>
#include <cctype>
#include <chrono>
#include <fstream>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include "utils.h"

namespace {
constexpr char kMarkerStart[] = "# BEGIN PERSONAL WORKBENCH MANAGED BLOCK";
constexpr char kMarkerEnd[] = "# END PERSONAL WORKBENCH MANAGED BLOCK";

std::wstring HostsPath() {
  std::vector<wchar_t> system_path(32768);
  const UINT length = GetSystemDirectoryW(
      system_path.data(), static_cast<UINT>(system_path.size()));
  if (length == 0 || length >= system_path.size()) return {};
  return std::wstring(system_path.data(), length) + L"\\drivers\\etc\\hosts";
}

bool ReadText(const std::wstring& path, std::string* content) {
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  if (!input) return false;
  const auto size = input.tellg();
  if (size < 0 || size > 16 * 1024 * 1024) return false;
  content->resize(static_cast<size_t>(size));
  input.seekg(0, std::ios::beg);
  return size == 0 || input.read(content->data(), size).good();
}

bool WriteText(const std::wstring& path, const std::string& content) {
  const std::wstring temporary = path + L".personal_workbench.tmp";
  {
    std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
    if (!output || !output.write(content.data(),
                                 static_cast<std::streamsize>(content.size()))) {
      DeleteFileW(temporary.c_str());
      return false;
    }
  }
  if (!MoveFileExW(temporary.c_str(), path.c_str(),
                   MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
    DeleteFileW(temporary.c_str());
    return false;
  }
  return true;
}

std::string Trim(std::string value) {
  const auto first = value.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) return {};
  const auto last = value.find_last_not_of(" \t\r\n");
  value = value.substr(first, last - first + 1);
  std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return value;
}

std::vector<std::string> NormalizeDomains(
    const std::vector<std::string>& domains) {
  std::set<std::string> normalized;
  for (auto domain : domains) {
    domain = Trim(domain);
    const auto scheme = domain.find("://");
    if (scheme != std::string::npos) domain.erase(0, scheme + 3);
    const auto path = domain.find_first_of("/?#");
    if (path != std::string::npos) domain.erase(path);
    const auto port = domain.find(':');
    if (port != std::string::npos) domain.erase(port);
    while (!domain.empty() && domain.front() == '.') domain.erase(domain.begin());
    while (!domain.empty() && domain.back() == '.') domain.pop_back();
    const bool valid = !domain.empty() &&
                       domain.find("..") == std::string::npos &&
                       std::all_of(domain.begin(), domain.end(), [](unsigned char c) {
                         return std::isalnum(c) || c == '.' || c == '-';
                       });
    if (!valid) continue;
    normalized.insert(domain);
    if (domain.rfind("www.", 0) != 0) normalized.insert("www." + domain);
  }
  return {normalized.begin(), normalized.end()};
}

std::string RemoveManagedBlock(std::string content) {
  const auto start = content.find(kMarkerStart);
  if (start == std::string::npos) return content;
  const auto marker_end = content.find(kMarkerEnd, start);
  if (marker_end == std::string::npos) return content;
  auto end = content.find('\n', marker_end);
  if (end == std::string::npos) {
    end = content.size();
  } else {
    ++end;
  }
  content.erase(start, end - start);
  return content;
}

std::string BuildManagedBlock(const std::vector<std::string>& domains) {
  std::ostringstream output;
  output << kMarkerStart << "\r\n";
  for (const auto& domain : NormalizeDomains(domains)) {
    output << "0.0.0.0 " << domain << "\r\n";
    output << ":: " << domain << "\r\n";
  }
  output << kMarkerEnd << "\r\n";
  return output.str();
}

void FlushDns() {
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION process{};
  std::wstring command = L"ipconfig.exe /flushdns";
  if (CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
                     CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process)) {
    WaitForSingleObject(process.hProcess, 10000);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
  }
}

void BackupHosts(const std::wstring& hosts_path) {
  PWSTR local_app_data = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_DEFAULT,
                                  nullptr, &local_app_data))) {
    return;
  }
  const std::wstring root =
      std::wstring(local_app_data) + L"\\PersonalWorkbench";
  CoTaskMemFree(local_app_data);
  const std::wstring backups = root + L"\\hosts_backups";
  CreateDirectoryW(root.c_str(), nullptr);
  CreateDirectoryW(backups.c_str(), nullptr);
  const auto stamp = std::chrono::system_clock::now().time_since_epoch().count();
  const std::wstring destination =
      backups + L"\\hosts-" + std::to_wstring(stamp) + L".bak";
  CopyFileW(hosts_path.c_str(), destination.c_str(), TRUE);
}

bool ApplyDirect(const std::vector<std::string>& domains) {
  const auto normalized = NormalizeDomains(domains);
  if (normalized.empty()) return false;
  const std::wstring path = HostsPath();
  std::string content;
  if (path.empty() || !ReadText(path, &content)) return false;
  BackupHosts(path);
  content = RemoveManagedBlock(std::move(content));
  if (!content.empty() && content.back() != '\n') content += "\r\n";
  content += BuildManagedBlock(normalized);
  if (!WriteText(path, content)) return false;
  FlushDns();
  return true;
}

bool ClearDirect() {
  const std::wstring path = HostsPath();
  std::string content;
  if (path.empty() || !ReadText(path, &content)) return false;
  const std::string cleaned = RemoveManagedBlock(content);
  if (cleaned == content) return true;
  if (!WriteText(path, cleaned)) return false;
  FlushDns();
  return true;
}

std::wstring TemporaryDomainFile(const std::vector<std::string>& domains) {
  std::vector<wchar_t> directory(MAX_PATH);
  if (GetTempPathW(static_cast<DWORD>(directory.size()), directory.data()) == 0) {
    return {};
  }
  std::vector<wchar_t> file(MAX_PATH);
  if (GetTempFileNameW(directory.data(), L"pwr", 0, file.data()) == 0) return {};
  std::ofstream output(file.data(), std::ios::binary | std::ios::trunc);
  if (!output) return {};
  for (const auto& domain : NormalizeDomains(domains)) output << domain << "\n";
  return file.data();
}

bool RunElevated(const std::wstring& arguments) {
  std::vector<wchar_t> executable(32768);
  const DWORD length = GetModuleFileNameW(
      nullptr, executable.data(), static_cast<DWORD>(executable.size()));
  if (length == 0 || length >= executable.size()) return false;
  SHELLEXECUTEINFOW info{};
  info.cbSize = sizeof(info);
  info.fMask = SEE_MASK_NOCLOSEPROCESS;
  info.lpVerb = L"runas";
  info.lpFile = executable.data();
  info.lpParameters = arguments.c_str();
  info.nShow = SW_HIDE;
  if (!ShellExecuteExW(&info) || !info.hProcess) return false;
  const DWORD wait = WaitForSingleObject(info.hProcess, 30000);
  DWORD exit_code = 1;
  if (wait == WAIT_OBJECT_0) GetExitCodeProcess(info.hProcess, &exit_code);
  CloseHandle(info.hProcess);
  return wait == WAIT_OBJECT_0 && exit_code == 0;
}
}  // namespace

bool IsProcessAdministrator() {
  BOOL is_member = FALSE;
  SID_IDENTIFIER_AUTHORITY authority = SECURITY_NT_AUTHORITY;
  PSID administrators = nullptr;
  if (AllocateAndInitializeSid(&authority, 2, SECURITY_BUILTIN_DOMAIN_RID,
                               DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0,
                               &administrators)) {
    CheckTokenMembership(nullptr, administrators, &is_member);
    FreeSid(administrators);
  }
  return is_member == TRUE;
}

RestrictionHostsStatus GetRestrictionHostsStatus(
    const std::vector<std::string>& domains) {
  RestrictionHostsStatus status;
  status.administrator = IsProcessAdministrator();
  std::string content;
  if (!ReadText(HostsPath(), &content)) {
    status.error = "Unable to read the Windows hosts file";
    return status;
  }
  status.marker_present = content.find(kMarkerStart) != std::string::npos &&
                          content.find(kMarkerEnd) != std::string::npos;
  for (const auto& domain : NormalizeDomains(domains)) {
    if (content.find("0.0.0.0 " + domain) == std::string::npos ||
        content.find(":: " + domain) == std::string::npos) {
      status.missing_entries.push_back(domain);
    }
  }
  status.active = status.marker_present && status.missing_entries.empty();
  status.externally_modified =
      status.marker_present && !status.missing_entries.empty();
  return status;
}

bool ApplyRestrictionHostsPolicy(const std::vector<std::string>& domains,
                                 bool allow_elevation) {
  if (IsProcessAdministrator()) return ApplyDirect(domains);
  if (!allow_elevation) return false;
  const std::wstring file = TemporaryDomainFile(domains);
  if (file.empty()) return false;
  const bool result = RunElevated(L"--restriction-hosts-apply \"" + file + L"\"");
  DeleteFileW(file.c_str());
  return result;
}

bool ClearRestrictionHostsPolicy(bool allow_elevation) {
  if (IsProcessAdministrator()) return ClearDirect();
  if (!allow_elevation) return false;
  return RunElevated(L"--restriction-hosts-clear");
}

int RunRestrictionHostsWorker(const std::vector<std::string>& arguments) {
  if (arguments.empty()) return -1;
  if (arguments[0] == "--restriction-hosts-clear") {
    return ClearRestrictionHostsPolicy(false) ? 0 : 1;
  }
  if (arguments[0] != "--restriction-hosts-apply" || arguments.size() < 2) {
    return -1;
  }
  std::ifstream input(Utf16FromUtf8(arguments[1]), std::ios::binary);
  if (!input) return 1;
  std::vector<std::string> domains;
  std::string line;
  while (std::getline(input, line)) domains.push_back(line);
  return ApplyRestrictionHostsPolicy(domains, false) ? 0 : 1;
}
