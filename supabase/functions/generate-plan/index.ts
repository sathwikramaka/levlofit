// POST /generate-plan
// Reads the user's saved answers, protocol settings and assessed goal levels (RLS as the user), runs the plan
// engine, adds the coach's level-by-level roadmap built from the curriculum checks (rules, no language model),
// stores an immutable plan snapshot and opens the dashboard gate. Every number comes from the engine.
import { withSupabase } from 'npm:@supabase/server@1.9.1';
import { buildRoadmap, generatePlan, type LevelRow, validateInput } from '../_shared/plan-engine.ts';
import { checkLimits, LIMITS } from '../_shared/rate.ts';

// Levels 4 and 5 need a tested pass, which has no server path yet; a client-written level is never trusted above 3.
export const MAX_SELF_ASSESSED_LEVEL = 3;

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405 });
    const userId = ctx.userClaims!.id;
    if ((await checkLimits(ctx.supabase, [LIMITS.planDay])) === 'limited') {
      return Response.json({ error: 'You have rebuilt your plan many times today. Try again tomorrow.' }, { status: 429 });
    }

    const [profile, goals, diet, levels] = await Promise.all([
      ctx.supabase.from('profiles').select('display_name, birth_year, sex, height_cm, weight_kg, weight_goal, body_type, days_per_week, session_minutes, daily_activity, sleep_hours, health_flags, injuries, equipment, equipment_items, training_days, training_time').eq('id', userId).single(),
      ctx.supabase
        .from('user_goals')
        .select('goal, experience, goal_catalog(name, kind, coach_led_from_level)')
        .eq('user_id', userId)
        .order('priority', { ascending: true }),
      ctx.supabase.from('dietary_profiles').select('diet_type, restrictions, other_restrictions, supplements, diet_pace, health_conditions').eq('user_id', userId).maybeSingle(),
      ctx.supabase.from('goal_levels').select('goal, level').eq('user_id', userId),
    ]);
    // A failed levels read would silently plan from the self-rating instead of the assessed level: fail, save nothing.
    if (profile.error || goals.error || diet.error || levels.error) return Response.json({ error: 'Could not read your answers' }, { status: 500 });
    if (!profile.data.birth_year || !diet.data) return Response.json({ error: 'Finish onboarding first' }, { status: 409 });
    // A goal without its catalogue row (removed from the catalogue, or not readable) cannot be planned.
    if (goals.data.some((g) => !g.goal_catalog)) {
      console.error(JSON.stringify({ event: 'goal_catalog_missing' }));
      return Response.json({ error: 'One of your goals is no longer available. Edit your goals and try again.' }, { status: 409 });
    }

    const assessed = new Map((levels.data ?? []).map((l) => [l.goal as string, Math.min(l.level as number, MAX_SELF_ASSESSED_LEVEL)]));
    const p = profile.data;
    let input;
    try {
      input = validateInput({
        ageYears: new Date().getUTCFullYear() - p.birth_year,
        sex: p.sex,
        heightCm: Number(p.height_cm),
        weightKg: Number(p.weight_kg),
        weightGoal: p.weight_goal,
        goals: goals.data.map((g) => {
          const c = g.goal_catalog as unknown as { name: string; kind: string; coach_led_from_level: number | null };
          return {
            goal: g.goal,
            experience: g.experience,
            name: c.name,
            kind: c.kind,
            coachLedFromLevel: c.coach_led_from_level,
            ...(assessed.has(g.goal) ? { currentLevel: assessed.get(g.goal) } : {}),
          };
        }),
        diet: diet.data.diet_type,
        restrictions: diet.data.restrictions,
        otherRestrictions: diet.data.other_restrictions,
        // 2.0 intake (null when the user answered before these questions existed)
        bodyType: p.body_type ?? undefined,
        daysPerWeek: p.days_per_week ?? undefined,
        sessionMinutes: p.session_minutes ?? undefined,
        dailyActivity: p.daily_activity ?? undefined,
        sleepHours: p.sleep_hours == null ? undefined : Number(p.sleep_hours),
        healthFlags: p.health_flags,
        injuries: p.injuries ?? undefined,
        equipment: p.equipment ?? undefined,
        equipmentItems: p.equipment_items,
        supplements: diet.data.supplements,
        pace: diet.data.diet_pace ?? undefined,
        // Build my plate health conditions (migration 20261029100000); absent before it, so older rows plan as before.
        conditions: diet.data.health_conditions ?? undefined,
        // Training weekdays and time (migration 20261029300000); absent before it, so older rows plan as before.
        trainingDays: p.training_days ?? undefined,
        trainingTime: p.training_time ?? undefined,
      });
    } catch (e) {
      // The plan engine's own checks throw a plain Error with a readable reason; anything else (a TypeError from an
      // unexpected shape) is logged and answered generically, so internals never reach the app.
      if (e instanceof Error && e.constructor === Error) return Response.json({ error: e.message }, { status: 400 });
      console.error(JSON.stringify({ event: 'plan_input_unexpected', kind: e instanceof Error ? e.name : typeof e }));
      return Response.json({ error: 'Could not read your answers' }, { status: 400 });
    }

    const plan = generatePlan(input);
    // The coach's path: curriculum level checks for each goal, assembled by rules.
    const checks = await ctx.supabase.from('curriculum_levels').select('goal, level, title, practice, advance_when').in('goal', plan.goals.map((g) => g.goal));
    // A failed read would silently store a plan without its level checks; fail before saving instead.
    if (checks.error) return Response.json({ error: 'Could not build your plan' }, { status: 500 });
    const stored = { ...plan, roadmap: buildRoadmap(plan, (checks.data ?? []) as LevelRow[], new Set(assessed.keys())) };

    const saved = await ctx.supabaseAdmin
      .from('generated_plans')
      .insert({ user_id: userId, engine_version: plan.engineVersion, input, plan: stored })
      .select('id')
      .single();
    if (saved.error) return Response.json({ error: 'Could not save plan' }, { status: 500 });

    const gate = await ctx.supabaseAdmin.from('profiles').update({ onboarding_complete: true }).eq('id', userId);
    if (gate.error) return Response.json({ error: 'Could not save plan' }, { status: 500 });

    return Response.json({ id: saved.data.id, plan: stored }, { status: 201 });
  }),
};
