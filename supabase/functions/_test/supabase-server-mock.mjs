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
        if (rec.op === 'select') return { data: cfg.data ?? null, error: cfg.error ?? null };
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
