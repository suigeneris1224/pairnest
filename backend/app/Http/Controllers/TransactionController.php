<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Models\Wallet;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class TransactionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'month' => ['nullable', 'date_format:Y-m'],
            'q' => ['nullable', 'string', 'max:100'],
            'type' => ['nullable', Rule::in(Transaction::TYPES)],
            'from' => ['nullable', 'date_format:Y-m-d', 'required_with:to'],
            'to' => ['nullable', 'date_format:Y-m-d', 'required_with:from', 'after_or_equal:from'],
            // Activity loads a whole month or range at once; keep pages for other callers.
            'per_page' => ['nullable', 'integer', 'min:1', 'max:500'],
        ]);
        if (isset($filters['from'], $filters['to'])
            && CarbonImmutable::parse($filters['from'])->diffInDays(CarbonImmutable::parse($filters['to'])) > 366) {
            throw ValidationException::withMessages(['to' => 'Pick a range of a year or less.']);
        }

        $query = $request->user()->couple->transactions()
            ->with('user:id,name')
            ->latest('occurred_on')->latest('id');

        if ($month = $filters['month'] ?? null) {
            $query->where('occurred_on', 'like', $month.'-%');
        }
        if ($q = $filters['q'] ?? null) {
            $query->where('title', 'like', '%'.addcslashes($q, '%_\\').'%');
        }
        if ($type = $filters['type'] ?? null) {
            $query->where('type', $type);
        }
        if (isset($filters['from'], $filters['to'])) {
            $query->whereBetween('occurred_on', [$filters['from'], $filters['to']]);
        }

        return response()->json($query->paginate($filters['per_page'] ?? 30));
    }

    public function store(Request $request): JsonResponse
    {
        // user_id is who paid: the sender unless they logged it for their partner.
        $data = $this->validated($request) + ['user_id' => $request->user()->id];
        $transaction = $request->user()->couple->transactions()->create($this->withWallet($request, $data, $data['user_id']));

        return response()->json($transaction->load('user:id,name'), 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $transaction = $request->user()->couple->transactions()->findOrFail($id);
        if ($transaction->type === 'transfer') {
            throw ValidationException::withMessages(['type' => "Transfers can't be edited. Delete it and transfer again."]);
        }
        if ($transaction->type === 'release') {
            throw ValidationException::withMessages(['type' => 'Restore the goal instead.']);
        }
        if ($transaction->type === 'move') {
            throw ValidationException::withMessages(['type' => "Moves can't be edited. Delete it and move the money again."]);
        }
        $data = $this->validated($request, partial: true);
        $transaction->update($this->withWallet($request, $data, $data['user_id'] ?? $transaction->user_id));

        return response()->json($transaction->load('user:id,name'));
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $transaction = $request->user()->couple->transactions()->findOrFail($id);
        if ($transaction->type === 'release') {
            throw ValidationException::withMessages(['type' => 'Restore the goal instead.']);
        }
        $transaction->delete();

        return response()->json(null, 204);
    }

    /**
     * Checks the wallet belongs to whoever paid (or is shared) and sets the
     * payment_method tag from it. A null wallet_id clears it.
     */
    private function withWallet(Request $request, array $data, int $payerId): array
    {
        if (! empty($data['wallet_id'])) {
            $wallet = Wallet::usable($request->user()->couple, $data['wallet_id'], $payerId);
            $data['payment_method'] = $wallet->paymentMethod();
        }

        return $data;
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $req = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'type' => [$req, Rule::in(['expense', 'income'])],
            'amount' => [$req, 'numeric', 'gt:0', 'max:9999999999'],
            'category' => [$req, Rule::in(Transaction::CATEGORIES)],
            'title' => [$req, 'string', 'max:120'],
            'payment_method' => ['sometimes', Rule::in(Transaction::PAYMENT_METHODS)],
            'is_split' => ['sometimes', 'boolean'],
            'wallet_id' => ['sometimes', 'nullable', 'integer'],
            'occurred_on' => [$req, 'date_format:Y-m-d'],
            'user_id' => ['sometimes', 'integer', Rule::in($request->user()->couple->members()->pluck('id'))],
        ]);
    }
}
