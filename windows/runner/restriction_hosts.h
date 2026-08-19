#ifndef RUNNER_RESTRICTION_HOSTS_H_
#define RUNNER_RESTRICTION_HOSTS_H_

#include <string>
#include <vector>

struct RestrictionHostsStatus {
  bool supported = true;
  bool administrator = false;
  bool active = false;
  bool marker_present = false;
  bool externally_modified = false;
  std::vector<std::string> missing_entries;
  std::string error;
};

bool IsProcessAdministrator();
RestrictionHostsStatus GetRestrictionHostsStatus(
    const std::vector<std::string>& domains);
bool ApplyRestrictionHostsPolicy(const std::vector<std::string>& domains,
                                 bool allow_elevation = true);
bool ClearRestrictionHostsPolicy(bool allow_elevation = true);
int RunRestrictionHostsWorker(const std::vector<std::string>& arguments);

#endif  // RUNNER_RESTRICTION_HOSTS_H_
