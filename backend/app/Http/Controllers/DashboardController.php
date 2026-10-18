<?php

namespace App\Http\Controllers;

use App\Services\BudgetSummary;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $couple = $request->user()->couple->load('members');
        $now = CarbonImmutable::now();

        return response()->json([
            'couple' => $couple,
            'budget' => BudgetSummary::for($couple, $now),
            // Every expense category this month (budgeted or not), for the donut.
            'spending' => (object) BudgetSummary::spentByCategory($couple, $now)->all(),
            // Money moved into goals this month; savings, not spending.
            // Releases from cancelled goals give savings back.
            'saved_this_month' => max(0, round(
                (float) $couple->transactions()->where('type', 'transfer')->where('occurred_on', 'like', $now->format('Y-m').'-%')->sum('amount')
                - (float) $couple->transactions()->where('type', 'release')->where('occurred_on', 'like', $now->format('Y-m').'-%')->sum('amount'),
                2,
            )),
            'last_month_spent' => round(BudgetSummary::spentByCategory($couple, $now->subMonthNoOverflow())->sum(), 2),
            // Overdue bills and those due in the next two weeks, soonest first.
            'upcoming_bills' => $couple->bills()->with('user:id,name')
                ->where('next_due_on', '<=', $now->addDays(14)->toDateString())
                ->orderBy('next_due_on')->limit(5)->get(),
            'wallets' => WalletController::listFor($couple, $request->user()->id),
            // Both partners' pay schedules, soonest first.
            'paydays' => $couple->paydays()->with('user:id,name')->orderBy('next_on')->orderBy('id')->get(),
            'recent' => $couple->transactions()->with('user:id,name')
                ->latest('occurred_on')->latest('id')->limit(5)->get(),
        ]);
    }
}
