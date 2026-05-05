'use strict';

// ── Dummy API ──────────────────────────────────────────────────────────────────
// Mock responses for all API endpoints. Loaded before app.js; app.js selects
// this backend when MODE === 'TEST'.
//
// Wrapped in an IIFE so local Ok/Err don't collide with app.js declarations.

const dummyApi = (() => {

  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

  // ── Mock data ────────────────────────────────────────────────────────────────

  const lastName = path => path.split('/').filter(Boolean).at(-1) ?? path;

  const makeTree = dir => ({
    name: lastName(dir) || 'root',
    type: 'dir',
    path: '',
    children: [
      {
        name: 'src', type: 'dir', path: 'src',
        children: [
          { name: 'Main.hs',       type: 'file', path: 'src/Main.hs'       },
          { name: 'Types.hs',      type: 'file', path: 'src/Types.hs'      },
          { name: 'Cli.hs',        type: 'file', path: 'src/Cli.hs'        },
          { name: 'FileSystem.hs', type: 'file', path: 'src/FileSystem.hs' },
        ],
      },
      {
        name: 'web', type: 'dir', path: 'web',
        children: [
          { name: 'index.html', type: 'file', path: 'web/index.html' },
          { name: 'style.css',  type: 'file', path: 'web/style.css'  },
          { name: 'app.js',     type: 'file', path: 'web/app.js'     },
          { name: 'dummy.js',   type: 'file', path: 'web/dummy.js'   },
        ],
      },
      {
        name: 'test', type: 'dir', path: 'test',
        children: [
          { name: 'Spec.hs', type: 'file', path: 'test/Spec.hs' },
        ],
      },
      { name: 'README.md',       type: 'file', path: 'README.md'       },
      { name: 'CHANGELOG.md',    type: 'file', path: 'CHANGELOG.md'    },
      { name: 'cabal.project',   type: 'file', path: 'cabal.project'   },
      { name: 'project.cabal',   type: 'file', path: 'project.cabal'   },
    ],
  });

  // ── Endpoint handlers ─────────────────────────────────────────────────────────

  const handleGetJSON = async url => {
    if (url.startsWith('/api/tree')) {
      await delay(180);
      const dir = decodeURIComponent(new URL(url, 'http://x').searchParams.get('dir') ?? '');
      return Ok(makeTree(dir));
    }
    return Err('[dummy] Unknown GET endpoint: ' + url);
  };

  const handlePostJSON = async (url, body) => {
    if (url === '/api/clone') {
      await delay(500);
      const repoSlug = (body.url.split('/').at(-1) ?? 'repo').replace(/\.git$/, '');
      const dir = 'repos/' + repoSlug;
      return Ok({ dir, tree: makeTree(repoSlug) });
    }
    if (url === '/api/context/append') {
      await delay(250);
      const bytes = body.entries.reduce((acc, _) => acc + 800 + Math.floor(Math.random() * 600), 0);
      return Ok({ appended: body.entries.length, bytes });
    }
    return Err('[dummy] Unknown POST endpoint: ' + url);
  };

  return { getJSON: handleGetJSON, postJSON: handlePostJSON };

})();
