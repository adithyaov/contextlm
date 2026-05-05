'use strict';

// ── Maybe ──────────────────────────────────────────────────────────────────────

const Just    = value => ({ tag: 'Just', value });
const Nothing = { tag: 'Nothing' };

const mapMaybe   = f => m => m.tag === 'Just' ? Just(f(m.value)) : Nothing;
const chainMaybe = f => m => m.tag === 'Just' ? f(m.value)       : Nothing;
const getOrElse  = d => m => m.tag === 'Just' ? m.value          : d;
const nullable   = x => x != null ? Just(x) : Nothing;

// ── Result ─────────────────────────────────────────────────────────────────────

const Ok  = value => ({ tag: 'Ok',  value });
const Err = error => ({ tag: 'Err', error });

const mapResult   = f             => r => r.tag === 'Ok' ? Ok(f(r.value))    : r;
const chainResult = f             => r => r.tag === 'Ok' ? f(r.value)        : r;
const foldResult  = (onErr, onOk) => r => r.tag === 'Ok' ? onOk(r.value) : onErr(r.error);
