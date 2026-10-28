<?php

namespace App\Http\Controllers;

use App\Models\Couple;
use App\Models\Wallet;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class WalletController extends Controller
{
    /** Active wallets the couple can see, shared ones first, each with its balance (or null when private). */
    public static function listFor(Couple $couple, int $viewerId): array
    {
        $flows = Wallet::flows($couple->id);

        return $couple->wallets()->active()->with('user:id,name')
            ->orderByRaw('user_id is not null')->orderBy('id')->get()
            ->map(fn (Wallet $w) => $w->presentFor($viewerId, $flows))
            ->all();
    }

    public function index(Request $request): JsonResponse
    {
        return response()->json(self::listFor($request->user()->couple, $request->user()->id));
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);
        $shared = $data['is_shared'] ?? false;
        unset($data['is_shared'], $data['balance']);
        $wallet = $request->user()->couple->wallets()->create($data + [
            'user_id' => $shared ? null : $request->user()->id,
            'opening_balance' => $request->input('balance', 0),
        ]);

        return $this->show($request, $wallet, 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $wallet = $this->editable($request, $id);
        $data = $this->validated($request, partial: true);
        unset($data['is_shared'], $data['balance']);
        if ($wallet->builtin) {
            // The built-in Cash wallet can be renamed, but stays cash.
            unset($data['kind'], $data['provider']);
        }
        $wallet->update($data);

        return $this->show($request, $wallet);
    }

    /** Sets what the wallet holds now, e.g. after checking the bank app. */
    public function balance(Request $request, int $id): JsonResponse
    {
        $wallet = $this->editable($request, $id);
        $data = $request->validate(['balance' => ['required', 'numeric', 'decimal:0,2', 'between:-9999999999,9999999999']]);
        $flows = Wallet::flows($wallet->couple_id);
        $wallet->update(['opening_balance' => round($data['balance'] - ($flows[$wallet->id] ?? 0), 2)]);

        // The flows don't change with the opening balance.
        return $this->show($request, $wallet, flows: $flows);
    }

    /** Deletes an unused wallet; one with history is archived so its transactions keep their label. */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $wallet = $this->editable($request, $id);
        if ($wallet->builtin) {
            throw ValidationException::withMessages(['wallet' => "{$wallet->name} is built in. You can rename it or correct its balance, but not remove it."]);
        }
        $couple = $request->user()->couple;
        $used = $couple->transactions()
            ->where(fn ($q) => $q->where('wallet_id', $wallet->id)->orWhere('to_wallet_id', $wallet->id))
            ->exists()
            || $couple->settlements()
                ->where(fn ($q) => $q->where('from_wallet_id', $wallet->id)->orWhere('to_wallet_id', $wallet->id))
                ->exists();
        $used ? $wallet->update(['archived_at' => CarbonImmutable::now()]) : $wallet->delete();

        return response()->json(null, 204);
    }

    private function show(Request $request, Wallet $wallet, int $status = 200, ?array $flows = null): JsonResponse
    {
        return response()->json(
            $wallet->load('user:id,name')->presentFor($request->user()->id, $flows ?? Wallet::flows($wallet->couple_id)),
            $status,
        );
    }

    /** Your own wallets and shared ones can be changed; a partner's personal wallet can't. */
    private function editable(Request $request, int $id): Wallet
    {
        $wallet = $request->user()->couple->wallets()->active()->with('user:id,name')->findOrFail($id);
        if (! $wallet->usableBy($request->user()->id)) {
            $name = $wallet->user->name;
            abort(403, "Only {$name} can change {$name}'s wallet.");
        }

        return $wallet;
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $req = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$req, 'string', 'max:60'],
            'kind' => [$req, Rule::in(Wallet::KINDS)],
            'provider' => ['sometimes', Rule::in(Wallet::PROVIDERS)],
            'last4' => ['sometimes', 'nullable', 'digits:4'],
            'balance' => ['sometimes', 'numeric', 'decimal:0,2', 'between:-9999999999,9999999999'],
            'is_shared' => ['sometimes', 'boolean'],
            'show_balance_to_partner' => ['sometimes', 'boolean'],
        ]);
    }
}
