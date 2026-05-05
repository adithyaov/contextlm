'use strict';

// ── Utilities ──────────────────────────────────────────────────────────────────

const esc = s =>
  String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');

const sortNodes = nodes =>
  [...nodes].sort((a, b) =>
    a.type !== b.type
      ? (a.type === 'dir' ? -1 : 1)
      : a.name.localeCompare(b.name)
  );

// ── HTTP (AsyncResult) ─────────────────────────────────────────────────────────
// MODE selects the API backend. Switch to 'TEST' to use dummy.js mock responses.
const MODE = 'PROD'; // 'PROD' | 'TEST'

const api = MODE === 'TEST' ? dummyApi : liveApi;

// ── Log (IO) ───────────────────────────────────────────────────────────────────

const appendLogIO = (msg, cls = 'info') => IO(() => {
  const el = document.getElementById('log');
  el.innerHTML += '\n<span class="' + cls + '">' + esc(msg) + '</span>';
  el.scrollTop = el.scrollHeight;
});

// ── DOM element builder ────────────────────────────────────────────────────────
// Pure helper: creates an element, sets properties, appends children.
// `dataset` key is handled specially to populate `element.dataset`.

const h = (tag, props = {}, children = []) => {
  const node = document.createElement(tag);
  Object.entries(props).forEach(([k, v]) => {
    if (k === 'dataset') Object.entries(v).forEach(([dk, dv]) => { node.dataset[dk] = dv; });
    else node[k] = v;
  });
  children.forEach(child =>
    typeof child === 'string' ? node.append(child) : node.appendChild(child)
  );
  return node;
};

// ── Tree rendering (pure) ──────────────────────────────────────────────────────

const makeCb = (repoDir, relPath, isDir) =>
  h('input', {
    type:    'checkbox',
    dataset: { repoDir, relPath, isDir: isDir ? '1' : '0' },
  });

const buildFileNode = (node, repoDir) =>
  h('label', { className: 'tree-file' }, [
    makeCb(repoDir, node.path, false),
    h('span', { className: 'file-icon', textContent: '—' }),
    ' ' + node.name,
  ]);

const buildDirNode = (node, repoDir, depth = 0) => {
  const det = h('details', { open: depth === 0 }, [
    h('summary', {}, [
      makeCb(repoDir, node.path ?? '', true),
      h('span', { className: 'dir-arrow', textContent: '▶' }),
      ' ' + node.name,
    ]),
  ]);
  sortNodes(node.children ?? []).forEach(child =>
    det.appendChild(buildNode(child, repoDir, depth + 1))
  );
  return det;
};

// Forward reference safe: buildDirNode closes over buildNode; by the time any
// node is rendered, buildNode is fully initialised.
const buildNode = (node, repoDir, depth = 0) =>
  node.type === 'file' ? buildFileNode(node, repoDir) : buildDirNode(node, repoDir, depth);

const buildRepoCard = (dir, tree) =>
  h('div', { className: 'repo', dataset: { dir } }, [
    h('div', { className: 'repo-header' }, [
      h('div', {}, [
        h('span', { className: 'repo-name', textContent: tree.name }),
        h('span', { className: 'repo-path', textContent: dir }),
      ]),
      h('div', { className: 'repo-acts' }, [
        h('button', { className: 'ghost js-all',    textContent: 'all'    }),
        h('button', { className: 'ghost js-none',   textContent: 'none'   }),
        h('button', { className: 'ghost js-remove', textContent: 'remove' }),
      ]),
    ]),
    h('div', { className: 'repo-tree' }, [buildNode(tree, dir)]),
  ]);

// ── Checkbox state (pure) ─────────────────────────────────────────────────────
// Computes the correct checked/indeterminate state for a parent checkbox
// given all checkboxes under it (including itself).

const computeParentState = (parentCb, allUnder) => {
  const others = allUnder.filter(c => c !== parentCb);
  const n = others.filter(c => c.checked && !c.indeterminate).length;
  if (n === 0)             return { checked: false, indeterminate: false };
  if (n === others.length) return { checked: true,  indeterminate: false };
  return                          { checked: false, indeterminate: true  };
};

// ── Checkbox effects (IO) ─────────────────────────────────────────────────────

const pushDownIO = cb => IO(() => {
  [...cb.closest('details').querySelectorAll('input[type=checkbox]')]
    .filter(c => c !== cb)
    .forEach(c => { c.checked = cb.checked; c.indeterminate = false; });
});

const bubbleUpIO = cb => IO(() => {
  const step = current => {
    const parentDet = current.closest('details')?.parentElement?.closest('details');
    if (!parentDet) return;
    const parentCb = parentDet.querySelector(':scope > summary > input[type=checkbox]');
    if (!parentCb) return;
    const state = computeParentState(
      parentCb,
      [...parentDet.querySelectorAll('input[type=checkbox]')]
    );
    parentCb.checked = state.checked;
    parentCb.indeterminate = state.indeterminate;
    step(parentCb);
  };
  step(cb);
});

const setAllIO = (card, checked) => IO(() =>
  [...card.querySelectorAll('input[type=checkbox]')]
    .forEach(c => { c.checked = checked; c.indeterminate = false; })
);

// ── Repo card effects (IO) ────────────────────────────────────────────────────

const renderRepoIO = (dir, tree) => IO(() => {
  const existing = document.querySelector(`.repo[data-dir="${CSS.escape(dir)}"]`);
  if (existing) existing.remove();
  document.getElementById('repos').appendChild(buildRepoCard(dir, tree));
});

// ── Actions ────────────────────────────────────────────────────────────────────

const collectEntriesIO = IO(() =>
  [...document.querySelectorAll('input[type=checkbox][data-is-dir="0"]:checked')]
    .map(cb => ({ dir: cb.dataset.repoDir, path: cb.dataset.relPath }))
);

const readOutputIO = IO(() =>
  document.getElementById('output-input').value.trim()
);

const loadRepo = dir =>
  bindIO(appendLogIO('Loading ' + dir + '…'))(() =>
  bindIO(IO(() => api.getJSON('/api/tree?dir=' + encodeURIComponent(dir))))(result =>
    foldResult(
      err  => appendLogIO('Failed to load ' + dir + ': ' + err, 'err'),
      tree => seqIO([renderRepoIO(dir, tree), appendLogIO('Loaded ' + dir, 'ok')])
    )(result)
  ));

const appendContext = () =>
  bindIO(collectEntriesIO)(entries =>
  bindIO(readOutputIO)(output => {
    if (!entries.length) return appendLogIO('No files selected.', 'err');
    if (!output)         return appendLogIO('No output file specified.', 'err');
    return (
      bindIO(appendLogIO('Appending ' + entries.length + ' file(s) → ' + output + '…'))(() =>
      bindIO(IO(() => api.postJSON('/api/context/append', { entries, output })))(result =>
        foldResult(
          err                   => appendLogIO('Error: ' + err, 'err'),
          ({ appended, bytes }) => appendLogIO('Done — ' + appended + ' file(s), ' + bytes + ' bytes written.', 'ok')
        )(result)
      ))
    );
  }));

// ── Event handlers ─────────────────────────────────────────────────────────────

document.getElementById('repos').addEventListener('change', e => {
  const cb = e.target;
  if (cb.type !== 'checkbox') return;
  runIO(cb.dataset.isDir === '1'
    ? seqIO([pushDownIO(cb), bubbleUpIO(cb)])
    : bubbleUpIO(cb)
  );
});

document.getElementById('repos').addEventListener('click', e => {
  const card = e.target.closest('.repo');
  if (!card) return;
  const cl = e.target.classList;
  if      (cl.contains('js-all'))    runIO(setAllIO(card, true));
  else if (cl.contains('js-none'))   runIO(setAllIO(card, false));
  else if (cl.contains('js-remove')) card.remove();
});

document.getElementById('append-btn').addEventListener('click', () =>
  runIO(appendContext())
);

document.getElementById('load-btn').addEventListener('click', () => {
  const input = document.getElementById('dir-input');
  const dir = input.value.trim();
  if (dir) { runIO(loadRepo(dir)); input.value = ''; }
});

document.getElementById('dir-input').addEventListener('keydown', e => {
  if (e.key !== 'Enter') return;
  const dir = e.target.value.trim();
  if (dir) { runIO(loadRepo(dir)); e.target.value = ''; }
});
