'use strict';

// ── Live API ───────────────────────────────────────────────────────────────────
// Real fetch-based implementations of all API endpoints.
// Loaded before app.js; app.js selects this backend when MODE === 'PROD'.

const liveApi = (() => {

  const handleGetJSON = async url => {
    try {
      const res = await fetch(url);
      return res.ok ? Ok(await res.json()) : Err(await res.text());
    } catch (e) {
      return Err(e.message);
    }
  };

  const handlePostJSON = async (url, body) => {
    try {
      const res = await fetch(url, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(body),
      });
      return res.ok ? Ok(await res.json()) : Err(await res.text());
    } catch (e) {
      return Err(e.message);
    }
  };

  return { getJSON: handleGetJSON, postJSON: handlePostJSON };

})();
