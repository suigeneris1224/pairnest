<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Services\BudgetSummary;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class BudgetController extends Controller
{
    public function show(Request $request, string $month): JsonResponse
    {
        return response()->json(BudgetSummary::for($request->user()->couple, $this->parseMonth($month)));
    }

    public function upsert(Request $request, string $month): JsonResponse
    {
        $data = $request->validate([
            'total' => ['required', 'numeric', 'min:0', 'max:9999999999'],
            'lines' => ['array'],
            'lines.*.category' => ['required', 'distinct', Rule::in(array_diff(Transaction::CATEGORIES, ['income']))],
            'lines.*.limit_amount' => ['required', 'numeric', 'min:0', 'max:9999999999'],
        ]);

        $couple = $request->user()->couple;
        $start = $this->parseMonth($month);

        DB::transaction(function () use ($couple, $start, $data) {
            $budget = $couple->budgets()->whereDate('month', $start->toDateString())->first()
                ?? $couple->budgets()->make(['month' => $start->toDateString()]);
            $budget->total = $data['total'];
            $budget->save();

            $budget->lines()->delete();
            $budget->lines()->createMany($data['lines'] ?? []);
        });

        return response()->json(BudgetSummary::for($couple, $start));
    }

    private function parseMonth(string $month): CarbonImmutable
    {
        abort_unless(preg_match('/^\d{4}-(0[1-9]|1[0-2])$/', $month), 422, 'Month must be YYYY-MM.');

        return CarbonImmutable::createFromFormat('!Y-m', $month);
    }
}
