'use strict';

// ── Mode ──────────────────────────────────────────────────────────────────────
const MODE = 'PROD'; // 'PROD' | 'TEST'
const api  = MODE === 'TEST' ? dummyApi : liveApi;

// ── State ─────────────────────────────────────────────────────────────────────
const state = {
  repos:       [],
  urlInput:    '',
  outputInput: 'context.xml',
  log:         [{ msg: 'Ready.', cls: 'info' }],
};

// ── State helpers ─────────────────────────────────────────────────────────────

const addLog = (msg, cls = 'info') => state.log.push({ msg, cls });

const addRepo = (dir, tree) => {
  state.repos = state.repos.filter(r => r.dir !== dir);
  state.repos.push({
    dir,
    tree,
    checked:  new Set(),
    openDirs: new Set(['']),  // root open by default
  });
};

// ── Tree helpers ──────────────────────────────────────────────────────────────

const sortNodes = nodes =>
  [...nodes].sort((a, b) =>
    a.type !== b.type ? (a.type === 'dir' ? -1 : 1) : a.name.localeCompare(b.name)
  );

const allFilePaths = node =>
  node.type === 'file'
    ? [node.path]
    : (node.children ?? []).flatMap(allFilePaths);

const dirCheckState = (node, checked) => {
  const paths = allFilePaths(node);
  const n = paths.filter(p => checked.has(p)).length;
  if (n === 0)            return 'unchecked';
  if (n === paths.length) return 'checked';
  return                         'indeterminate';
};

const setDirChecked = (node, checked, value) =>
  allFilePaths(node).forEach(p => value ? checked.add(p) : checked.delete(p));

// ── Actions ───────────────────────────────────────────────────────────────────

const loadRepo = url => {
  addLog('Cloning ' + url + '…');
  api.postJSON('/api/clone', { url }).then(result => {
    foldResult(
      err             => addLog('Failed: ' + err, 'err'),
      ({ dir, tree }) => { addRepo(dir, tree); addLog('Loaded ' + dir, 'ok'); }
    )(result);
    m.redraw();
  });
};

const appendContext = () => {
  const entries = state.repos.flatMap(r =>
    [...r.checked].map(path => ({ dir: r.dir, path }))
  );
  if (!entries.length)       { addLog('No files selected.', 'err'); return; }
  if (!state.outputInput)    { addLog('No output file specified.', 'err'); return; }
  addLog('Appending ' + entries.length + ' file(s) → ' + state.outputInput + '…');
  api.postJSON('/api/context/append', { entries, output: state.outputInput }).then(result => {
    foldResult(
      err                   => addLog('Error: ' + err, 'err'),
      ({ appended, bytes }) => addLog('Done — ' + appended + ' file(s), ' + bytes + ' bytes written.', 'ok')
    )(result);
    m.redraw();
  });
};

// ── Components ────────────────────────────────────────────────────────────────

const FileRow = {
  view({ attrs: { node, repo } }) {
    return m('label.tree-file', [
      m('input[type=checkbox]', {
        checked:  repo.checked.has(node.path),
        onchange: e =>
          e.target.checked ? repo.checked.add(node.path) : repo.checked.delete(node.path),
      }),
      m('span.file-icon', '—'),
      ' ' + node.name,
    ]);
  },
};

const DirRow = {
  view({ attrs: { node, repo, depth } }) {
    const st   = dirCheckState(node, repo.checked);
    const open = repo.openDirs.has(node.path);
    const syncIndeterminate = ({ dom }) => { dom.indeterminate = st === 'indeterminate'; };
    return m('details', {
      open,
      ontoggle: e =>
        e.target.open ? repo.openDirs.add(node.path) : repo.openDirs.delete(node.path),
    }, [
      m('summary', [
        m('input[type=checkbox]', {
          checked:  st === 'checked',
          oncreate: syncIndeterminate,
          onupdate: syncIndeterminate,
          onchange: e => setDirChecked(node, repo.checked, e.target.checked),
          onclick:  e => e.stopPropagation(),
        }),
        m('span.dir-arrow', '▶'),
        ' ' + node.name,
      ]),
      ...sortNodes(node.children ?? []).map(child =>
        m(child.type === 'file' ? FileRow : DirRow, { node: child, repo, depth: depth + 1 })
      ),
    ]);
  },
};

const RepoCard = {
  view({ attrs: { repo } }) {
    return m('.repo', [
      m('.repo-header', [
        m('div', [
          m('span.repo-name', repo.tree.name),
          m('span.repo-path', ' ' + repo.dir),
        ]),
        m('.repo-acts', [
          m('button.ghost', { onclick: () => setDirChecked(repo.tree, repo.checked, true)  }, 'all'),
          m('button.ghost', { onclick: () => setDirChecked(repo.tree, repo.checked, false) }, 'none'),
          m('button.ghost', { onclick: () => { state.repos = state.repos.filter(r => r !== repo); } }, 'remove'),
        ]),
      ]),
      m('.repo-tree', m(DirRow, { node: repo.tree, repo, depth: 0 })),
    ]);
  },
};

const LogPanel = {
  oncreate: ({ dom }) => { dom.scrollTop = dom.scrollHeight; },
  onupdate: ({ dom }) => { dom.scrollTop = dom.scrollHeight; },
  view() {
    return m('pre#log',
      state.log.map(({ msg, cls }) => m('span', { class: cls }, msg + '\n'))
    );
  },
};

// ── App ───────────────────────────────────────────────────────────────────────

const App = {
  view() {
    return m('main', [
      m('h1', 'contextlm'),

      m('.panel', [
        m('.panel-title', 'Repository'),
        m('.row', [
          m('input[type=text]', {
            placeholder: 'https://github.com/user/repo',
            value:       state.urlInput,
            oninput:     e => { state.urlInput = e.target.value; },
            onkeydown:   e => {
              if (e.key !== 'Enter' || !state.urlInput.trim()) return;
              loadRepo(state.urlInput.trim());
              state.urlInput = '';
            },
          }),
          m('button', {
            onclick: () => {
              if (!state.urlInput.trim()) return;
              loadRepo(state.urlInput.trim());
              state.urlInput = '';
            },
          }, 'Load'),
        ]),
      ]),

      state.repos.map(repo => m(RepoCard, { key: repo.dir, repo })),

      m('.panel', [
        m('.panel-title', 'Output'),
        m('.row', [
          m('input[type=text]', {
            value:       state.outputInput,
            placeholder: '/path/to/context.xml',
            oninput:     e => { state.outputInput = e.target.value; },
          }),
          m('button.primary', { onclick: appendContext }, 'Append Context'),
        ]),
      ]),

      m('.panel', [
        m('.panel-title', 'Log'),
        m(LogPanel),
      ]),
    ]);
  },
};

m.mount(document.body, App);
