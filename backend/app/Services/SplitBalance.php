<?php

namespace App\Services;

use App\Models\Couple;
use App\Models\Settlement;
use Carbon\CarbonImmutable;

class SplitBalance
{
    /**
     * Who owes whom, as a running total: each split expense is shared 50/50,
     * personal ones don't count, and settlements pay the difference back.
     * Spending from a shared wallet doesn't count either: both of you filled
     * it, so instead each partner's top-ups into shared wallets are listed.
     * Null until the partner has joined.
     */
    public static function for(Couple $couple, CarbonImmutable $now): ?array
    {
        $members = $couple->members()->orderBy('id')->get(['id', 'name']);
        if ($members->count() < 2) {
            return null;
        }
        [$a, $b] = [$members[0], $members[1]];

        $shared = $couple->wallets()->whereNull('user_id')->pluck('id');
        $expenses = fn () => $couple->transactions()->where('type', 'expense');
        $splitPaid = $expenses()->where('is_split', true)
            ->where(fn ($q) => $q->whereNull('wallet_id')->orWhereNotIn('wallet_id', $shared))
            ->groupBy('user_id')->selectRaw('user_id, sum(amount) as total')->pluck('total', 'user_id');
        $paidThisMonth = $expenses()->inMonth($now)
            ->groupBy('user_id')->selectRaw('user_id, sum(amount) as total')->pluck('total', 'user_id');
        $toppedUp = $couple->transactions()->where('type', 'move')->whereIn('to_wallet_id', $shared)
            // Moving between two shared wallets isn't anyone's contribution.
            ->whereNotIn('wallet_id', $shared)
            ->inMonth($now)
            ->groupBy('user_id')->selectRaw('user_id, sum(amount) as total')->pluck('total', 'user_id');
        $sharedSpent = (float) $expenses()->whereIn('wallet_id', $shared)->inMonth($now)->sum('amount');
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
                'topped_up_this_month' => round($paid($toppedUp, $m), 2),
            ])->values(),
            'shared_spent_this_month' => round($sharedSpent, 2),
            'settlements' => $couple->settlements()->with(Settlement::WITH)
                ->latest('settled_on')->latest('id')->limit(10)->get(),
        ];
    }
}
