// 预览稿共享脚本：主题切换（跟随 localStorage，默认亮色）
(function () {
  var saved = null;
  try { saved = localStorage.getItem("pwb-v2-theme"); } catch (e) {}
  var prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
  var theme = saved || (prefersDark ? "dark" : "light");
  document.documentElement.setAttribute("data-theme", theme);

  window.toggleTheme = function () {
    var cur = document.documentElement.getAttribute("data-theme");
    var next = cur === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    try { localStorage.setItem("pwb-v2-theme", next); } catch (e) {}
    var btn = document.querySelector(".theme-toggle .label");
    if (btn) btn.textContent = next === "dark" ? "切换亮色" : "切换暗色";
  };
})();
