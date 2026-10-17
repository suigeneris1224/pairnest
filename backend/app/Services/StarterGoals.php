<?php

namespace App\Services;

use App\Models\Couple;
use App\Models\User;
use Carbon\CarbonImmutable;

/**
 * Turns onboarding answers into a nest's first savings goals and budget.
 * Targets are friendly starting points; couples edit them later.
 */
class StarterGoals
{
    /** Goal keys people can pick, with name, icon and starting target. */
    public const GOALS = [
        'emergency' => ['Emergency Fund', 'shield', 50000],
        'home' => ['Our Home', 'home', 500000],
        'travel' => ['Travel Fund', 'travel', 60000],
        'wedding' => ['Our Wedding', 'ring', 300000],
        'debt_free' => ['Debt-Free', 'star', 100000],
        'car' => ['Car', 'car', 300000],
        'retirement' => ['Retirement', 'retire', 1000000],
        'business' => ['Our Business', 'business', 200000],
        // Family goals.
        'getting_married' => ['Our Wedding', 'ring', 300000],
        'kids' => ['Baby Fund', 'baby', 150000],
        'education' => ["Kids' Education", 'school', 500000],
        'parents' => ["Parents' Care", 'home', 100000],
        'pet' => ['Pet Fund', 'pet', 30000],
    ];

    public const FINANCIAL = ['emergency', 'home', 'travel', 'wedding', 'debt_free', 'car', 'retirement', 'business'];

    public const FAMILY = ['getting_married', 'kids', 'education', 'parents', 'pet'];

    /** Adds the user's picked goals the nest doesn't have yet (matched by name). */
    public static function addGoals(Couple $couple, User $user): void
    {
        $profile = $user->profile ?? [];
        $picked = array_merge($profile['financial_goals'] ?? [], $profile['family_goals'] ?? []);
        $existing = $couple->goals()->pluck('name')->map(fn ($n) => mb_strtolower($n))->all();

        foreach ($picked as $key) {
            [$name, $icon, $target] = self::GOALS[$key] ?? [null, null, null];
            if ($name === null || in_array(mb_strtolower($name), $existing, true)) {
                continue;
            }
            $couple->goals()->create(['name' => $name, 'icon' => $icon, 'target_amount' => $target]);
            $existing[] = mb_strtolower($name);
        }
    }

    /** A brand-new nest: goals, this month's budget, and the relationship stage. */
    public static function forNewNest(Couple $couple, User $user): void
    {
        $profile = $user->profile ?? [];
        self::addGoals($couple, $user);

        $budget = (float) ($profile['monthly_budget'] ?? 0);
        if ($budget > 0) {
            $couple->budgets()->create(['month' => CarbonImmutable::now()->startOfMonth()->toDateString(), 'total' => $budget]);
        }
        if (! empty($profile['stage'])) {
            $couple->update(['stage' => $profile['stage']]);
        }
    }
}
