<?php

namespace App\Services;

use App\Models\Couple;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;

class BudgetSummary
{
    /**
     * Budget vs. actual expenses for one month, overall and per category.
     */
    public static function for(Couple $couple, CarbonImmutable $month): array
    {
        $start = $month->startOfMonth();
        $budget = $couple->budgets()->with('lines')->whereDate('month', $start->toDateString())->first();
        $spentByCategory = static::spentByCategory($couple, $start);

        $total = $budget?->total ?? 0.0;
        $spent = round($spentByCategory->sum(), 2);

        $lines = ($budget?->lines ?? collect())->map(function ($line) use ($spentByCategory) {
            $spent = $spentByCategory->get($line->category, 0.0);

            return [
                'category' => $line->category,
                'limit' => $line->limit_amount,
                'spent' => $spent,
                'remaining' => round($line->limit_amount - $spent, 2),
                'percent' => $line->limit_amount > 0 ? (int) round($spent / $line->limit_amount * 100) : 0,
            ];
        })->values();

        return [
            'month' => $start->format('Y-m'),
            'total' => $total,
            'spent' => $spent,
            'remaining' => round($total - $spent, 2),
            'percent' => $total > 0 ? (int) round($spent / $total * 100) : 0,
            'lines' => $lines,
        ];
    }

    /**
     * Expense totals per category for one month, largest first.
     *
     * @return \Illuminate\Support\Collection<string, float>
     */
    public static function spentByCategory(Couple $couple, CarbonImmutable $month): Collection
    {
        $start = $month->startOfMonth();

        return $couple->transactions()
            ->where('type', 'expense')
            ->whereBetween('occurred_on', [$start->toDateString(), $start->endOfMonth()->toDateString()])
            ->selectRaw('category, SUM(amount) as spent')
            ->groupBy('category')
            ->pluck('spent', 'category')
            ->map(fn ($v) => round((float) $v, 2))
            ->sortDesc();
    }
}
