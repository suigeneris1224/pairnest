<?php

namespace App\Services;

use App\Models\Couple;
use Carbon\CarbonImmutable;

class SplitBalance
{
    /**
     * Who owes whom, as a running total: each split expense is shared 50/50,
     * personal ones don't count, and settlements pay the difference back.
     * Null until the partner has joined.
     */
    public static function for(Couple $couple, CarbonImmutable $now): ?array
    {
        $members = $couple->members()->orderBy('id')->get(['id', 'name']);
        if ($members->count() < 2) {
            return null;
        }
        [$a, $b] = [$members[0], $members[1]];

        $expenses = fn () => $couple->transactions()->where('type', 'expense');
        $splitPaid = $expenses()->where('is_split', true)
            ->groupBy('user_id')->selectRaw('user_id, sum(amount) as total')->pluck('total', 'user_id');
        $paidThisMonth = $expenses()->where('occurred_on', 'like', $now->format('Y-m').'-%')
            ->groupBy('user_id')->selectRaw('user_id, sum(amount) as total')->pluck('total', 'user_id');
        $settledOut = $couple->settlements()
            ->groupBy('from_user_id')->selectRaw('from_user_id, sum(amount) as total')->pluck('total', 'from_user_id');

        $paid = fn ($map, $user) => (float) ($map[$user->id] ?? 0);

        // Positive: B owes A. Negative: A owes B.
        $net = round(
            ($paid($splitPaid, $a) - $paid($splitPaid, $b)) / 2 - $paid($settledOut, $b) + $paid($settledOut, $a),
            2,
        );

        $owes = null;
        if (abs($net) >= 0.01) {
            [$from, $to] = $net > 0 ? [$b, $a] : [$a, $b];
            $owes = [
                'from' => ['id' => $from->id, 'name' => $from->name],
                'to' => ['id' => $to->id, 'name' => $to->name],
                'amount' => abs($net),
            ];
        }

        return [
            'owes' => $owes,
            'members' => $members->map(fn ($m) => [
                'id' => $m->id,
                'name' => $m->name,
                'split_paid' => round($paid($splitPaid, $m), 2),
                'paid_this_month' => round($paid($paidThisMonth, $m), 2),
            ])->values(),
            'settlements' => $couple->settlements()->with('from:id,name', 'to:id,name')
                ->latest('settled_on')->latest('id')->limit(10)->get(),
        ];
    }
}
