// Test double for `npm:@supabase/server`, used only by node tests (never deployed).
// withSupabase() hands the handler whatever context the test placed on globalThis.__supabaseCtx.
export function withSupabase(_options, handler) {
  return (req) => handler(req, globalThis.__supabaseCtx);
}

// A tiny chainable fake of the supabase-js query builder. It records every call and answers from `tables`:
//   tables[name] = { data, error, insertError, deleteError }
// Records land in `ops` as { table, op, args, filters } so tests can assert what was read or written.
export function fakeClient(tables, ops = []) {
  return {
    ops,
    // Database functions: tables['rpc:<name>'] is { data, error } or (args) => { data, error }. Unconfigured functions
    // answer like PostgREST does for a function that does not exist (PGRST202), as before a migration is applied.
    rpc(name, args) {
      ops.push({ table: `rpc:${name}`, op: 'rpc', args, filters: [] });
      const cfg = tables[`rpc:${name}`];
      const out = typeof cfg === 'function' ? cfg(args) : cfg ?? { data: null, error: { code: 'PGRST202', message: `Could not find the function public.${name}` } };
      return Promise.resolve(out);
    },
    from(table) {
      const rec = { table, op: 'select', args: null, filters: [] };
      const cfg = tables[table] ?? {};
      const result = () => {
        if (rec.op === 'insert' && cfg.insertError) return { data: null, error: cfg.insertError };
        if (rec.op === 'delete' && cfg.deleteError) return { data: null, error: cfg.deleteError };
        if (rec.op === 'insert') {
          const rows = Array.isArray(rec.args) ? rec.args : [rec.args];
          return { data: rows.map((_, i) => ({ id: (cfg.nextId ?? 100) + i })), error: null };
        }
        if (rec.op === 'select') {
          // cfg.select(filters) answers filtered reads; otherwise every read of the table returns cfg.data.
          if (typeof cfg.select === 'function') return cfg.select(rec.filters);
          return { data: cfg.data ?? null, error: cfg.error ?? null };
        }
        return { data: null, error: null };
      };
      const b = {
        select() { return b; },
        insert(args) { rec.op = 'insert'; rec.args = args; return b; },
        update(args) { rec.op = 'update'; rec.args = args; return b; },
        upsert(args) { rec.op = 'upsert'; rec.args = args; return b; },
        delete() { rec.op = 'delete'; return b; },
        eq(c, v) { rec.filters.push(['eq', c, v]); return b; },
        gte(c, v) { rec.filters.push(['gte', c, v]); return b; },
        gt(c, v) { rec.filters.push(['gt', c, v]); return b; },
        lt(c, v) { rec.filters.push(['lt', c, v]); return b; },
        in(c, v) { rec.filters.push(['in', c, v]); return b; },
        order() { return b; },
        limit(n) { rec.limit = n; return b; },
        single() { return Promise.resolve(single(result())); },
        maybeSingle() { return Promise.resolve(single(result())); },
        then(resolve, reject) { return Promise.resolve(result()).then(resolve, reject); },
      };
      ops.push(rec); // one record per query; op and args are filled in by the chain
      return b;
    },
  };
}

function single(r) {
  if (r.error || r.data == null) return r;
  return { data: Array.isArray(r.data) ? r.data[0] ?? null : r.data, error: null };
}

// A fake Supabase Storage bucket API, following the documented list() behaviour: entries directly under a prefix,
// sorted by name, paged by limit (default 100) and offset; nested objects show up as folder entries with id null
// and metadata null. `paths` are full object paths. Options inject failures:
//   listError(callNumber, prefix) -> true to fail that list call; removeError: every remove fails;
//   stuck: remove reports success but deletes nothing (a folder that never empties).
export function fakeStorage(paths, options = {}) {
  const objects = new Set(paths);
  const calls = { list: [], remove: [] };
  return {
    objects,
    calls,
    from() {
      return {
        async list(prefix = '', { limit = 100, offset = 0 } = {}) {
          calls.list.push(prefix);
          if (options.listError?.(calls.list.length, prefix)) return { data: null, error: { message: 'list failed' } };
          const base = prefix ? `${prefix}/` : '';
          const entries = new Map();
          for (const o of objects) {
            if (!o.startsWith(base)) continue;
            const rest = o.slice(base.length);
            const cut = rest.indexOf('/');
            if (cut < 0) entries.set(rest, { name: rest, id: `id:${o}`, metadata: {} });
            else if (!entries.has(rest.slice(0, cut))) entries.set(rest.slice(0, cut), { name: rest.slice(0, cut), id: null, metadata: null });
          }
          const sorted = [...entries.values()].sort((a, b) => a.name.localeCompare(b.name));
          return { data: sorted.slice(offset, offset + limit), error: null };
        },
        async remove(list) {
          calls.remove.push([...list]);
          if (options.removeError) return { data: null, error: { message: 'remove failed' } };
          if (!options.stuck) for (const p of list) objects.delete(p);
          return { data: list.map((name) => ({ name })), error: null };
        },
      };
    },
  };
}
