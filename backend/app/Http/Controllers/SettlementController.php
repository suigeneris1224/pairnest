<?php

namespace App\Http\Controllers;

use App\Services\SplitBalance;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SettlementController extends Controller
{
    public function balance(Request $request): JsonResponse
    {
        return response()->json(
            SplitBalance::for($request->user()->couple, CarbonImmutable::now())
                ?? ['owes' => null, 'members' => [], 'settlements' => []]
        );
    }

    public function store(Request $request): JsonResponse
    {
        $couple = $request->user()->couple;
        $memberIds = $couple->members()->pluck('id');
        if ($memberIds->count() < 2) {
            throw ValidationException::withMessages(['from_user_id' => 'Your partner needs to join before you can settle up.']);
        }

        $data = $request->validate([
            'amount' => ['required', 'numeric', 'gt:0', 'max:9999999999'],
            'from_user_id' => ['required', 'integer', Rule::in($memberIds)],
            'settled_on' => ['sometimes', 'date_format:Y-m-d'],
        ]);

        $settlement = $couple->settlements()->create([
            'from_user_id' => $data['from_user_id'],
            'to_user_id' => $memberIds->first(fn ($id) => $id !== (int) $data['from_user_id']),
            'amount' => $data['amount'],
            'settled_on' => $data['settled_on'] ?? CarbonImmutable::now()->toDateString(),
        ]);

        return response()->json($settlement->load('from:id,name', 'to:id,name'), 201);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $request->user()->couple->settlements()->findOrFail($id)->delete();

        return response()->json(null, 204);
    }
}
