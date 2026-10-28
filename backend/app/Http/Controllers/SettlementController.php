<?php

namespace App\Http\Controllers;

use App\Models\Settlement;
use App\Models\Wallet;
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
            'amount' => ['required', 'numeric', 'decimal:0,2', 'gt:0', 'max:9999999999'],
            'from_user_id' => ['required', 'integer', Rule::in($memberIds)],
            'settled_on' => ['sometimes', 'date_format:Y-m-d', 'after_or_equal:2000-01-01', 'before:2100-01-01'],
            'from_wallet_id' => ['nullable', 'integer'],
            'to_wallet_id' => ['nullable', 'integer'],
        ]);
        $fromId = (int) $data['from_user_id'];
        $toId = $memberIds->first(fn ($id) => $id !== $fromId);

        $settlement = $couple->settlements()->create([
            'from_user_id' => $fromId,
            'to_user_id' => $toId,
            'from_wallet_id' => $this->ownWallet($request, $data['from_wallet_id'] ?? null, $fromId, 'from_wallet_id'),
            'to_wallet_id' => $this->ownWallet($request, $data['to_wallet_id'] ?? null, $toId, 'to_wallet_id'),
            'amount' => $data['amount'],
            'settled_on' => $data['settled_on'] ?? CarbonImmutable::now()->toDateString(),
        ]);

        return response()->json($settlement->load(Settlement::WITH), 201);
    }

    /**
     * $id when it's one of your own active wallets (not a shared one) on your
     * side of the settle-up, else a validation error. Your partner's wallets
     * are theirs to track.
     */
    private function ownWallet(Request $request, ?int $id, int $sideId, string $field): ?int
    {
        if ($id === null) {
            return null;
        }
        $me = $request->user();
        if ($sideId !== $me->id) {
            throw ValidationException::withMessages([$field => 'Only your partner can pick their wallet.']);
        }
        $wallet = $me->couple->wallets()->active()->find($id);
        if (! $wallet || $wallet->user_id !== $me->id) {
            throw ValidationException::withMessages([$field => 'Pick one of your own wallets.']);
        }

        return $wallet->id;
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $couple = $request->user()->couple;
        $settlement = $couple->settlements()->findOrFail($id);
        Wallet::ensureNotPartners($couple, $request->user()->id, $settlement->from_wallet_id, $settlement->to_wallet_id);
        $settlement->delete();

        return response()->json(null, 204);
    }
}
