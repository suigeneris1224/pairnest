<?php

namespace App\Http\Controllers;

use App\Models\Bill;
use App\Models\Transaction;
use App\Models\Wallet;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class BillController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        return response()->json(
            $request->user()->couple->bills()->with('user:id,name')->orderBy('next_due_on')->orderBy('id')->get()
        );
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);
        $this->checkWallet($request, $data);
        $bill = $request->user()->couple->bills()->create(
            $data + ['user_id' => $request->user()->id, 'anchor_day' => CarbonImmutable::parse($data['next_due_on'])->day]
        );

        return response()->json($bill->load('user:id,name'), 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $bill = $request->user()->couple->bills()->findOrFail($id);
        $data = $this->validated($request, partial: true);
        $this->checkWallet($request, $data);
        if (isset($data['next_due_on'])) {
            $data['anchor_day'] = CarbonImmutable::parse($data['next_due_on'])->day;
        }
        $bill->update($data);

        return response()->json($bill->load('user:id,name'));
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $request->user()->couple->bills()->findOrFail($id)->delete();

        return response()->json(null, 204);
    }

    /** Records this period's payment as an expense and moves the bill to its next due date. */
    public function pay(Request $request, int $id): JsonResponse
    {
        $bill = $request->user()->couple->bills()->findOrFail($id);
        $data = $request->validate([
            'payment_method' => ['sometimes', Rule::in(Transaction::PAYMENT_METHODS)],
            'wallet_id' => ['sometimes', 'nullable', 'integer'],
        ]);
        $couple = $request->user()->couple;
        // A wallet picked now must be usable; the bill's usual one is skipped if it isn't.
        $wallet = array_key_exists('wallet_id', $data)
            ? ($data['wallet_id'] === null ? null : Wallet::usable($couple, $data['wallet_id'], $request->user()->id))
            : Wallet::quietly($couple, $bill->wallet_id, $request->user()->id);

        $transaction = DB::transaction(function () use ($request, $bill, $data, $wallet) {
            $transaction = $request->user()->couple->transactions()->create([
                'user_id' => $request->user()->id,
                'type' => 'expense',
                'amount' => $bill->amount,
                'category' => $bill->category,
                'title' => $bill->title,
                'wallet_id' => $wallet?->id,
                'payment_method' => $wallet?->paymentMethod() ?? $data['payment_method'] ?? 'cash',
                'is_split' => $bill->is_split,
                'occurred_on' => CarbonImmutable::today()->toDateString(),
            ]);
            $bill->advance();
            $bill->save();

            return $transaction;
        });

        return response()->json([
            'bill' => $bill->load('user:id,name'),
            'transaction' => $transaction->load('user:id,name'),
        ], 201);
    }

    /**
     * Undo a payment: removes the expense it logged and puts the due date back.
     * anchor_day is left alone, so a bill on the 31st still returns to the 31st.
     */
    public function unpay(Request $request, int $id): JsonResponse
    {
        $couple = $request->user()->couple;
        $bill = $couple->bills()->findOrFail($id);
        $data = $request->validate([
            'transaction_id' => ['required', 'integer'],
            'next_due_on' => ['required', 'date_format:Y-m-d'],
        ]);

        $transaction = $couple->transactions()->find($data['transaction_id']);
        if (! $transaction || $transaction->type !== 'expense' || $transaction->title !== $bill->title
            || $transaction->category !== $bill->category || abs($transaction->amount - $bill->amount) >= 0.01) {
            throw ValidationException::withMessages(['transaction_id' => "That isn't this bill's payment."]);
        }

        DB::transaction(function () use ($bill, $transaction, $data) {
            $transaction->delete();
            $bill->next_due_on = $data['next_due_on'];
            $bill->save();
        });

        return response()->json($bill->load('user:id,name'));
    }

    private function checkWallet(Request $request, array $data): void
    {
        if (! empty($data['wallet_id'])) {
            Wallet::usable($request->user()->couple, $data['wallet_id'], $request->user()->id);
        }
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $req = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'title' => [$req, 'string', 'max:120'],
            'amount' => [$req, 'numeric', 'gt:0', 'max:9999999999'],
            'category' => [$req, Rule::in(array_diff(Transaction::CATEGORIES, ['income']))],
            'frequency' => ['sometimes', Rule::in(Bill::FREQUENCIES)],
            'next_due_on' => [$req, 'date_format:Y-m-d'],
            'is_split' => ['sometimes', 'boolean'],
            'wallet_id' => ['sometimes', 'nullable', 'integer'],
        ]);
    }
}
