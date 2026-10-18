<?php

namespace App\Http\Controllers;

use App\Models\Wallet;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Moves money between two wallets: topping up a shared wallet, paying off a
 * credit card, cashing out. Logged in Activity, never counted as spending.
 */
class MoveController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'from_wallet_id' => ['required', 'integer'],
            'to_wallet_id' => ['required', 'integer'],
            'amount' => ['required', 'numeric', 'gt:0', 'max:9999999999'],
            'note' => ['nullable', 'string', 'max:120'],
            'occurred_on' => ['sometimes', 'date_format:Y-m-d'],
        ]);
        if ((int) $data['from_wallet_id'] === (int) $data['to_wallet_id']) {
            throw ValidationException::withMessages(['to_wallet_id' => 'Pick two different wallets.']);
        }

        $me = $request->user();
        $couple = $me->couple;
        // Only from and to wallets you can use: yours or shared.
        $from = Wallet::usable($couple, $data['from_wallet_id'], $me->id, 'from_wallet_id');
        $to = Wallet::usable($couple, $data['to_wallet_id'], $me->id, 'to_wallet_id');

        $move = $couple->transactions()->create([
            'user_id' => $me->id,
            'wallet_id' => $from->id,
            'to_wallet_id' => $to->id,
            'type' => 'move',
            'amount' => $data['amount'],
            'category' => 'others',
            'title' => ($data['note'] ?? null) ?: "{$from->name} → {$to->name}",
            'payment_method' => $from->paymentMethod(),
            'is_split' => false,
            'occurred_on' => $data['occurred_on'] ?? CarbonImmutable::today()->toDateString(),
        ]);

        return response()->json([
            'transaction' => $move->load('user:id,name'),
            'wallets' => WalletController::listFor($couple, $me->id),
        ], 201);
    }
}
