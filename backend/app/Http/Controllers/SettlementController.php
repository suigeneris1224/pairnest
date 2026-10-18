<?php

namespace App\Http\Controllers;

use App\Models\Couple;
use App\Models\Settlement;
use App\Models\User;
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
            'from_wallet_id' => ['nullable', 'integer'],
            'to_wallet_id' => ['nullable', 'integer'],
        ]);
        $fromId = (int) $data['from_user_id'];
        $toId = $memberIds->first(fn ($id) => $id !== $fromId);

        $settlement = $couple->settlements()->create([
            'from_user_id' => $fromId,
            'to_user_id' => $toId,
            'from_wallet_id' => $this->personalWallet($couple, $data['from_wallet_id'] ?? null, $fromId, 'from_wallet_id'),
            'to_wallet_id' => $this->personalWallet($couple, $data['to_wallet_id'] ?? null, $toId, 'to_wallet_id'),
            'amount' => $data['amount'],
            'settled_on' => $data['settled_on'] ?? CarbonImmutable::now()->toDateString(),
        ]);

        return response()->json($settlement->load(Settlement::WITH), 201);
    }

    /** $id when it's one of $userId's own active wallets (not a shared one), else a validation error. */
    private function personalWallet(Couple $couple, ?int $id, int $userId, string $field): ?int
    {
        if ($id === null) {
            return null;
        }
        $wallet = $couple->wallets()->active()->find($id);
        if (! $wallet || $wallet->user_id !== $userId) {
            $name = $userId === request()->user()->id ? 'your' : User::find($userId)->name."'s";
            throw ValidationException::withMessages([$field => "Pick one of {$name} own wallets."]);
        }

        return $wallet->id;
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $request->user()->couple->settlements()->findOrFail($id)->delete();

        return response()->json(null, 204);
    }
}
