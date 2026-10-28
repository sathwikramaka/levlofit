"use client";

import { useMemo, useState } from "react";
// The app's own plan engine (copied from supabase/functions/_shared by "npm run engine" before every dev and build),
// so the website and the app can never disagree on the numbers.
import { ENGINE_VERSION, generatePlan, validateInput } from "@/lib/plan-engine";

const GOALS = [
  ["cut", "Lose fat"],
  ["maintain", "Stay the same"],
  ["bulk", "Gain muscle"],
] as const;

type Form = { age: string; sex: "male" | "female"; height: string; weight: string; goal: (typeof GOALS)[number][0]; days: string };

/** Runs the plan engine on a few answers. Returns the numbers, or the engine's own message for an answer out of range. */
export function estimate(f: Form) {
  try {
    const plan = generatePlan(
      validateInput({
        ageYears: Number(f.age),
        sex: f.sex,
        heightCm: Number(f.height),
        weightKg: Number(f.weight),
        weightGoal: f.goal,
        daysPerWeek: Number(f.days),
        goals: [{ goal: "strength", name: "Strength", kind: "strength", coachLedFromLevel: null, experience: "beginner" }],
        diet: "vegetarian",
        restrictions: [],
        otherRestrictions: [],
      }),
    );
    const n = plan.nutrition;
    return {
      ok: true as const,
      maintenance: n.energy.maintenanceKcal,
      target: n.energyKcal,
      protein: n.proteinG,
      notes: plan.review.filter((r) => r.level === "change" || r.level === "stop").map((r) => r.title),
    };
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Check your answers.";
    return { ok: false as const, error: msg.replace("ageYears", "Age").replace("heightCm", "Height (cm)").replace("weightKg", "Weight (kg)") + "." };
  }
}

const field = "h-12 w-full rounded-xl border border-line bg-surface px-4 text-[16px] outline-none focus:border-ink";

/** A try-before-you-install estimate. Nothing typed here leaves the page: no request, no storage. */
export function Estimate() {
  const [f, setF] = useState<Form>({ age: "25", sex: "male", height: "172", weight: "70", goal: "maintain", days: "3" });
  const r = useMemo(() => estimate(f), [f]);
  const set = (k: keyof Form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => setF({ ...f, [k]: e.target.value });
  const num = (k: "age" | "height" | "weight", label: string, unit: string) => (
    <div>
      <label htmlFor={`e-${k}`} className="mb-1.5 block text-[14px] font-semibold">
        {label} <span className="font-normal text-muted">({unit})</span>
      </label>
      <input id={`e-${k}`} inputMode="decimal" value={f[k]} onChange={set(k)} className={field} />
    </div>
  );
  return (
    <div className="grid gap-6 md:grid-cols-2">
      <form className="grid grid-cols-2 gap-4" onSubmit={(e) => e.preventDefault()} aria-label="Your details">
        {num("age", "Age", "years")}
        <div>
          <label htmlFor="e-sex" className="mb-1.5 block text-[14px] font-semibold">Sex</label>
          <select id="e-sex" value={f.sex} onChange={set("sex")} className={field}>
            <option value="male">Male</option>
            <option value="female">Female</option>
          </select>
        </div>
        {num("height", "Height", "cm")}
        {num("weight", "Weight", "kg")}
        <div>
          <label htmlFor="e-goal" className="mb-1.5 block text-[14px] font-semibold">Goal</label>
          <select id="e-goal" value={f.goal} onChange={set("goal")} className={field}>
            {GOALS.map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="e-days" className="mb-1.5 block text-[14px] font-semibold">Training days a week</label>
          <select id="e-days" value={f.days} onChange={set("days")} className={field}>
            {[2, 3, 4, 5, 6].map((d) => (
              <option key={d}>{d}</option>
            ))}
          </select>
        </div>
      </form>
      <div aria-live="polite" className="rounded-2xl border border-line bg-surface p-6">
        {r.ok ? (
          <>
            <p className="font-mono text-[11px] tracking-[0.2em] text-muted uppercase">Daily target</p>
            <p className="mt-2 font-mono text-[44px] leading-none font-medium tracking-tight">{r.target} kcal</p>
            <p className="mt-3 text-[15px] text-muted">
              Maintenance about {r.maintenance} kcal. Protein {r.protein} g a day.
            </p>
            {r.notes.length > 0 && (
              <ul className="mt-4 space-y-1 text-[15px]">
                {r.notes.map((n) => (
                  <li key={n}>Changed for you: {n}.</li>
                ))}
              </ul>
            )}
          </>
        ) : (
          <p className="text-[15px] text-danger">{r.error}</p>
        )}
        <p className="mt-5 text-[13px] leading-relaxed text-muted">
          An estimate from the same rules the app uses (plan engine {ENGINE_VERSION}), for a beginner strength goal. Not medical advice. The app also asks about
          your health, diet, activity and pace before setting your plan. Nothing you type here leaves this page.
        </p>
      </div>
    </div>
  );
}
