/* Local interactions for the high fidelity theme previews. */
const previewDialog = document.createElement('dialog');
previewDialog.className = 'preview-dialog';
previewDialog.setAttribute('aria-labelledby', 'preview-dialog-title');
document.body.append(previewDialog);
let timerId = null;
let timerSeconds = 45 * 60;

const escapeHtml = value => value.replace(/[&<>"']/g, character => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[character]));
const head = (eyebrow, title, description) => `<div class="dialog-head"><div><span class="dialog-eyebrow">${eyebrow}</span><h2 id="preview-dialog-title">${title}</h2><p>${description}</p></div><button class="dialog-close" type="button" aria-label="关闭">×</button></div>`;

function openDialog(content) {
  if (previewDialog.open) previewDialog.close();
  previewDialog.innerHTML = content;
  previewDialog.showModal();
  previewDialog.querySelector('input,button:not(.dialog-close)')?.focus();
}
function closeDialog() {
  if (previewDialog.open) previewDialog.close();
  clearInterval(timerId);
  timerId = null;
}
function toast(message) {
  document.querySelector('.preview-toast')?.remove();
  const node = document.createElement('div');
  node.className = 'preview-toast';
  node.setAttribute('role', 'status');
  node.textContent = message;
  document.body.append(node);
  setTimeout(() => node.remove(), 3200);
}

function showCapture() {
  openDialog(`${head('QUICK CAPTURE', '快速记下', '把想到的事放进今天，再继续当前工作。')}
    <form class="capture-form"><label for="capture-title">内容</label><input id="capture-title" name="title" maxlength="60" required placeholder="例如：补充方案评审要点" autocomplete="off">
    <div class="capture-fields"><div><label for="capture-kind">类型</label><select id="capture-kind" name="kind"><option value="task">任务</option><option value="note">灵感笔记</option></select></div><div><label for="capture-project">归属</label><select id="capture-project" name="project"><option>产品体验优化</option><option>收件箱</option></select></div></div>
    <div class="dialog-actions"><span>Enter 保存 · Esc 关闭</span><button class="primary-button" type="submit">${icon('plus')}保存记录</button></div></form>`);
}
function showFocus() {
  timerSeconds = 45 * 60;
  openDialog(`${head('FOCUS SESSION', '开始专注', '完成方案初稿 · 产品体验优化')}
    <div class="focus-dial"><span id="timer-value">45:00</span><small>保持节奏，专注这一件事</small></div>
    <div class="dialog-actions"><span>可随时暂停</span><button id="timer-toggle" class="primary-button" type="button">${icon('timer')}开始计时</button></div>`);
}
function showProjectCreation() {
  openDialog(`${head('NEW PROJECT', '新建项目', '给新的工作方向一个清晰的名字。')}
    <form class="project-form capture-form"><label for="project-name">项目名称</label><input id="project-name" name="name" maxlength="40" required placeholder="例如：客户研究计划" autocomplete="off">
    <div class="dialog-actions"><span>稍后可继续添加任务与笔记</span><button class="primary-button" type="submit">${icon('plus')}创建项目</button></div></form>`);
}
function showSearch() {
  const nodes = [...document.querySelectorAll('.task-title,.mobile-task strong')];
  openDialog(`${head('SEARCH', '搜索当前页面', '按任务名称查找，回到需要处理的内容。')}
    <label class="search-field">${icon('search')}<input id="preview-search" type="search" placeholder="搜索任务…" autocomplete="off"></label>
    <div class="search-results" role="listbox">${nodes.map((node, index) => `<button type="button" data-result="${index}" role="option">${icon('list')}<span>${node.textContent}</span>${icon('arrow')}</button>`).join('')}</div>`);
  previewDialog.taskNodes = nodes;
}
function showMobileMenu() {
  openDialog(`${head('WORKSPACE', '工作空间', '选择要查看的示例页面。')}
    <nav class="dialog-menu"><a href="?theme=${theme}&screen=mobile">${icon('calendar')}今日${icon('arrow')}</a><a href="?theme=${theme}&screen=projects">${icon('folder')}项目${icon('arrow')}</a></nav>`);
}

function prepareChecks() {
  document.querySelectorAll('.task-check').forEach(check => {
    check.tabIndex = 0;
    check.setAttribute('role', 'checkbox');
    check.setAttribute('aria-checked', String(check.classList.contains('checked')));
    check.setAttribute('aria-label', check.closest('.task-card,.mobile-task')?.querySelector('.task-title,strong')?.textContent || '任务');
  });
}
function syncCounts() {
  const list = document.querySelector('.project-task-list,.task-list,.mobile-task-list');
  if (!list) return;
  const cards = [...list.children].filter(node => node.matches('.task-card,.mobile-task'));
  const done = cards.filter(card => card.classList.contains('is-done')).length;
  const total = cards.length;
  const percent = Math.round(done / total * 100);
  if (list.classList.contains('project-task-list')) {
    document.querySelector('.project-tasks .section-count').textContent = `${total} 项 · 已完成 ${done} 项`;
    document.querySelector('.project-choice.selected small').textContent = `${total} 项任务 · 持续推进`;
    document.querySelector('.project-numbers strong').textContent = `${done} / ${total}`;
    document.querySelector('.project-percent').innerHTML = `${percent}%<small>总进度</small>`;
    document.querySelector('.project-hero-track i').style.width = `${percent}%`;
  } else if (list.classList.contains('task-list')) {
    document.querySelector('.tasks-section .section-count').textContent = `${total} 项`;
    document.querySelector('.hero-content .overline').lastChild.textContent = ` ${String(done).padStart(2,'0')} / ${String(total).padStart(2,'0')}`;
    document.querySelector('.hero-content p').textContent = `已完成 ${done} 件事，还有 ${total - done} 件值得专注完成。`;
    document.querySelector('.hero-stats span:first-child').innerHTML = `${icon('check')}${done} / ${total} 已完成`;
    const ring = document.querySelector('.progress-ring');
    ring.querySelector('span').textContent = `${percent}%`;
    ring.style.background = `conic-gradient(var(--primary) 0 ${percent}%,var(--ring-track) ${percent}% 100%)`;
  } else {
    document.querySelector('.mobile-section-title span').textContent = `${done} / ${total} 已完成`;
    document.querySelector('.mobile-overline span').textContent = `${String(done).padStart(2,'0')} / ${String(total).padStart(2,'0')}`;
    document.querySelector('.mobile-hero p').textContent = `已完成 ${done} 件，还有 ${total - done} 件待推进`;
    document.querySelector('.mobile-progress-line i').style.width = `${percent}%`;
    document.querySelector('.mobile-progress-value').textContent = `${percent}%`;
  }
}

document.addEventListener('click', event => {
  if (event.target.closest('.dialog-close')) return closeDialog();
  if (event.target.closest('.capture-button,.sidebar-note,.mobile-fab,.text-action,.mobile-header button[aria-label="记录"]')) return showCapture();
  if (event.target.closest('.header-create')) return showProjectCreation();
  if (event.target.closest('.mobile-header button[aria-label="菜单"]')) return showMobileMenu();
  if (event.target.closest('.focus-button,.mobile-next .primary-button')) return showFocus();
  if (event.target.closest('.search-button,.topbar-right .icon-button,.mobile-header button[aria-label="搜索"]')) return showSearch();
  if (event.target.closest('[data-preview-only]')) { event.preventDefault(); return toast('当前主题预览展示今日与项目页面'); }
  const check = event.target.closest('.task-check');
  if (check) {
    const card = check.closest('.task-card,.mobile-task');
    const done = !card.classList.contains('is-done');
    card.classList.toggle('is-done', done);
    check.classList.toggle('checked', done);
    check.innerHTML = done ? icon('check') : '';
    check.setAttribute('aria-checked', String(done));
    const status = card.querySelector('.task-status');
    if (status) { status.textContent = done ? '已完成' : '待开始'; status.className = `task-status ${done ? 'done' : 'pending'}`; }
    syncCounts();
    return;
  }
  const timerButton = event.target.closest('#timer-toggle');
  if (timerButton) {
    if (timerId) { clearInterval(timerId); timerId = null; timerButton.innerHTML = `${icon('timer')}继续计时`; }
    else { timerButton.innerHTML = `${icon('timer')}暂停计时`; timerId = setInterval(() => {
      timerSeconds = Math.max(0, timerSeconds - 1);
      previewDialog.querySelector('#timer-value').textContent = `${String(Math.floor(timerSeconds / 60)).padStart(2,'0')}:${String(timerSeconds % 60).padStart(2,'0')}`;
      if (!timerSeconds) { closeDialog(); toast('专注时间完成'); }
    }, 1000); }
    return;
  }
  const result = event.target.closest('[data-result]');
  if (result) {
    const node = previewDialog.taskNodes[Number(result.dataset.result)];
    closeDialog();
    const card = node?.closest('.task-card,.mobile-task');
    card?.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth',block:'center'});
    card?.classList.add('preview-highlight');
    setTimeout(() => card?.classList.remove('preview-highlight'), 1800);
  }
});

document.addEventListener('submit', event => {
  if (event.target.matches('.project-form')) {
    event.preventDefault();
    const name = event.target.elements.name.value.trim();
    if (!name) return event.target.elements.name.focus();
    const picker = document.querySelector('.project-picker');
    picker?.querySelector('.picker-note')?.insertAdjacentHTML('beforebegin', `<button class="project-choice"><span class="choice-symbol">${icon('folder')}</span><span><strong>${escapeHtml(name)}</strong><small>0 项任务 · 刚刚创建</small></span></button>`);
    const count = picker?.querySelector('.picker-heading b');
    if (count) count.textContent = String(Number(count.textContent) + 1).padStart(2,'0');
    closeDialog();
    toast('新项目已创建');
    return;
  }
  if (!event.target.matches('.capture-form')) return;
  event.preventDefault();
  const form = event.target;
  const title = form.elements.title.value.trim();
  if (!title) return form.elements.title.focus();
  const kind = form.elements.kind.value;
  const project = form.elements.project.value;
  if (kind === 'task') {
    const desktopList = document.querySelector('.task-list,.project-task-list');
    const mobileList = document.querySelector('.mobile-task-list');
    if (desktopList) desktopList.insertAdjacentHTML('beforeend', task({title:escapeHtml(title),meta:project,status:'待开始',due:'今天'}));
    if (mobileList) mobileList.insertAdjacentHTML('beforeend', `<div class="mobile-task"><span class="task-check"></span><div><strong>${escapeHtml(title)}</strong><small>${escapeHtml(project)} · 待开始</small></div></div>`);
    prepareChecks();
    syncCounts();
    toast('已加入当前清单');
  } else {
    const existing = JSON.parse(sessionStorage.getItem('preview-notes') || '[]');
    sessionStorage.setItem('preview-notes', JSON.stringify([...existing, {title,project}]));
    const noteBox = document.querySelector('.project-evidence .evidence-card:nth-child(2)');
    if (noteBox) noteBox.insertAdjacentHTML('beforeend', `<div class="note-link">${escapeHtml(title)} ${icon('arrow')}</div>`);
    toast('灵感已记下');
  }
  closeDialog();
});

document.addEventListener('input', event => {
  if (event.target.id !== 'preview-search') return;
  const query = event.target.value.trim().toLocaleLowerCase();
  previewDialog.querySelectorAll('[data-result]').forEach(button => { button.hidden = !button.textContent.toLocaleLowerCase().includes(query); });
});
document.addEventListener('keydown', event => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') { event.preventDefault(); showSearch(); }
  const check = event.target.closest('.task-check');
  if (check && (event.key === ' ' || event.key === 'Enter')) { event.preventDefault(); check.click(); }
});
previewDialog.addEventListener('click', event => { if (event.target === previewDialog) closeDialog(); });
previewDialog.addEventListener('close', () => { clearInterval(timerId); timerId = null; });
compactViewport.addEventListener('change', prepareChecks);
prepareChecks();
