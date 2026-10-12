// Node module hook for tests: maps Deno's `npm:@supabase/server` import to the local test double.
const mock = new URL('./supabase-server-mock.mjs', import.meta.url).href;

export async function resolve(specifier, context, next) {
  if (specifier.startsWith('npm:@supabase/server')) return { url: mock, shortCircuit: true };
  return next(specifier, context);
}
