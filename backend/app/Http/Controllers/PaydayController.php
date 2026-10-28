<?php

namespace App\Http\Controllers;

use App\Models\Payday;
use App\Models\Transaction;
use App\Models\Wallet;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class PaydayController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        return response()->json(
            $request->user()->couple->paydays()->with('user:id,name')->orderBy('next_on')->orderBy('id')->get()
        );
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);
        $this->checkWallet($request, $data);
        $payday = $request->user()->couple->paydays()->create(
            $this->withSchedule($data, $data['frequency']) + ['user_id' => $request->user()->id]
        );

        return response()->json($payday->load('user:id,name'), 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $payday = $this->owned($request, $id);
        $data = $this->validated($request, partial: true);
        $this->checkWallet($request, $data);
        if (array_intersect_key($data, array_flip(['frequency', 'days', 'next_on']))) {
            $data = $this->withSchedule($data, $data['frequency'] ?? $payday->frequency);
        }
        $payday->update($data);

        return response()->json($payday->load('user:id,name'));
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $this->owned($request, $id)->delete();

        return response()->json(null, 204);
    }

    /** Logs this payday's pay as income (the amount can differ) and moves on to the next one. */
    public function receive(Request $request, int $id): JsonResponse
    {
        $payday = $this->owned($request, $id);
        $data = $request->validate([
            'amount' => ['sometimes', 'numeric', 'decimal:0,2', 'gt:0', 'max:9999999999'],
            'payment_method' => ['sometimes', Rule::in(Transaction::PAYMENT_METHODS)],
        ]);

        $wallet = Wallet::quietly($request->user()->couple, $payday->wallet_id, $payday->user_id);

        $transaction = DB::transaction(function () use ($request, $payday, $data, $wallet) {
            $transaction = $request->user()->couple->transactions()->create([
                'user_id' => $payday->user_id,
                'wallet_id' => $wallet?->id,
                'type' => 'income',
                'amount' => $data['amount'] ?? $payday->amount,
                'category' => 'income',
                'title' => $payday->title,
                'payment_method' => $wallet?->paymentMethod() ?? $data['payment_method'] ?? 'bank',
                'is_split' => $payday->is_split,
                'occurred_on' => CarbonImmutable::today()->toDateString(),
            ]);
            $payday->advance();
            $payday->save();

            return $transaction;
        });

        return response()->json([
            'payday' => $payday->load('user:id,name'),
            'transaction' => $transaction->load('user:id,name'),
        ], 201);
    }

    /** Undo a receive: removes the income it logged and puts the payday back. */
    public function unreceive(Request $request, int $id): JsonResponse
    {
        $payday = $this->owned($request, $id);
        $data = $request->validate([
            'transaction_id' => ['required', 'integer'],
            'next_on' => ['required', 'date_format:Y-m-d', 'after_or_equal:2000-01-01', 'before:2100-01-01'],
        ]);

        $transaction = $request->user()->couple->transactions()->find($data['transaction_id']);
        if (! $transaction || $transaction->type !== 'income' || $transaction->title !== $payday->title
            || $transaction->user_id !== $payday->user_id) {
            throw ValidationException::withMessages(['transaction_id' => "That isn't this payday's income."]);
        }

        DB::transaction(function () use ($payday, $transaction, $data) {
            $transaction->delete();
            $payday->next_on = $data['next_on'];
            $payday->save();
        });

        return response()->json($payday->load('user:id,name'));
    }

    private function checkWallet(Request $request, array $data): void
    {
        if (! empty($data['wallet_id'])) {
            Wallet::usable($request->user()->couple, $data['wallet_id'], $request->user()->id);
        }
    }

    /** A payday in this couple that belongs to the signed-in partner. */
    private function owned(Request $request, int $id): Payday
    {
        $payday = $request->user()->couple->paydays()->with('user:id,name')->findOrFail($id);
        if ($payday->user_id !== $request->user()->id) {
            $name = $payday->user->name;
            abort(403, "Only {$name} can change {$name}'s payday.");
        }

        return $payday;
    }

    /** Turns days of the month (or a start date for weekly pay) into day_a, day_b and next_on. */
    private function withSchedule(array $data, string $frequency): array
    {
        if (in_array($frequency, Payday::BY_DAY, true)) {
            $days = array_map('intval', $data['days'] ?? []);
            sort($days);
            $count = $frequency === 'semimonthly' ? 2 : 1;
            if (count(array_unique($days)) !== $count) {
                throw ValidationException::withMessages([
                    'days' => $count === 2 ? 'Pick two different days of the month.' : 'Pick a day of the month.',
                ]);
            }
            $data['day_a'] = $days[0];
            $data['day_b'] = $days[1] ?? null;
            $data['next_on'] = Payday::firstOnOrAfter($days, CarbonImmutable::today())->toDateString();
        } else {
            if (! isset($data['next_on'])) {
                throw ValidationException::withMessages(['next_on' => 'Pick the next payday.']);
            }
            $data['day_a'] = $data['day_b'] = null;
        }
        $data['frequency'] = $frequency;
        unset($data['days']);

        return $data;
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $req = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'title' => ['sometimes', 'string', 'max:120'],
            'amount' => [$req, 'numeric', 'decimal:0,2', 'gt:0', 'max:9999999999'],
            'frequency' => [$req, Rule::in(Payday::FREQUENCIES)],
            'days' => ['sometimes', 'array', 'max:2'],
            'days.*' => ['integer', 'between:1,31'],
            'next_on' => ['sometimes', 'date_format:Y-m-d', 'after_or_equal:2000-01-01', 'before:2100-01-01'],
            'is_split' => ['sometimes', 'boolean'],
            'wallet_id' => ['sometimes', 'nullable', 'integer'],
        ]);
    }
}
