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

// ── IO ─────────────────────────────────────────────────────────────────────────

const IO      = run => ({ tag: 'IO', run });
const pureIO  = x   => IO(() => x);
const mapIO   = f   => io => IO(() => f(io.run()));
const chainIO = f   => io => IO(() => f(io.run()).run());
const seqIO   = ios => IO(() => ios.map(io => io.run()));

const runIO = io => io.run();

// Monadic bind (>>=): runs io, passes its result to f, runs the returned IO.
// Handles async IOs — run() may return a Promise.
const bindIO = io => f => IO(async () => (await f(await io.run())).run());
