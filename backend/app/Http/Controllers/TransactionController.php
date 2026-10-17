<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
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
        ]);

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

        return response()->json($query->paginate(30));
    }

    public function store(Request $request): JsonResponse
    {
        // user_id is who paid: the sender unless they logged it for their partner.
        $transaction = $request->user()->couple->transactions()->create(
            $this->validated($request) + ['user_id' => $request->user()->id]
        );

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
        $transaction->update($this->validated($request, partial: true));

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
            'occurred_on' => [$req, 'date_format:Y-m-d'],
            'user_id' => ['sometimes', 'integer', Rule::in($request->user()->couple->members()->pluck('id'))],
        ]);
    }
}
