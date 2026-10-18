<?php

namespace App\Http\Controllers;

use App\Models\Wallet;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Moves money between two wallets: topping up a shared wallet, paying off a
 * credit card, cashing out. Logged in Activity, never counted as spending;
 * a fee (InstaPay, ATM) is, as an expense from the same wallet tied to it.
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
            'fee' => ['nullable', 'numeric', 'gte:0', 'max:9999999999'],
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

        $on = $data['occurred_on'] ?? CarbonImmutable::today()->toDateString();
        $fee = round((float) ($data['fee'] ?? 0), 2);

        $move = DB::transaction(function () use ($couple, $me, $from, $to, $data, $on, $fee) {
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
                'occurred_on' => $on,
            ]);
            if ($fee > 0) {
                $couple->transactions()->create([
                    'user_id' => $me->id,
                    'wallet_id' => $from->id,
                    'move_id' => $move->id,
                    'type' => 'expense',
                    'amount' => $fee,
                    'category' => 'others',
                    'title' => "Fee · {$from->name} → {$to->name}",
                    'payment_method' => $from->paymentMethod(),
                    'is_split' => false,
                    'occurred_on' => $on,
                ]);
            }

            return $move;
        });

        return response()->json([
            'transaction' => $move->load('user:id,name'),
            'wallets' => WalletController::listFor($couple, $me->id),
        ], 201);
    }
}
