<?php

namespace App\Http\Controllers;

use App\Models\Goal;
use App\Models\GoalContribution;
use App\Models\Transaction;
use App\Models\Wallet;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GoalController extends Controller
{
    private const LIMIT = 200;

    public function index(Request $request): JsonResponse
    {
        $goals = $request->user()->couple->goals()
            ->withSum('contributions as saved', 'amount')
            // Active goals first; cancelled ones sink to the bottom.
            ->orderByRaw('cancelled_at is not null')
            ->latest()
            ->limit(self::LIMIT)
            ->get();
        // Who saved toward each goal, in one query rather than every contribution.
        $contributors = GoalContribution::whereIn('goal_id', $goals->pluck('id'))
            ->distinct()->get(['goal_id', 'user_id'])
            ->groupBy('goal_id')->map(fn ($rows) => $rows->pluck('user_id')->values());
        $goals = $goals->map(fn (Goal $goal) => $this->present($goal, $contributors->get($goal->id, collect())));

        return response()->json($goals);
    }

    public function store(Request $request): JsonResponse
    {
        $goal = $request->user()->couple->goals()->create($this->validated($request));

        return response()->json($this->present($goal->loadSum('contributions as saved', 'amount')), 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $goal = $request->user()->couple->goals()->findOrFail($id);
        $goal->update($this->validated($request, partial: true));

        return response()->json($this->present($goal->loadSum('contributions as saved', 'amount')));
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $couple = $request->user()->couple;
        $goal = $couple->goals()->findOrFail($id);
        // Deleting undoes the goal's transfers, so it can't reach into a partner's own wallets.
        $owner = $couple->wallets()
            ->whereIn('id', $couple->transactions()->where('goal_id', $goal->id)->whereNotNull('wallet_id')->select('wallet_id'))
            ->whereNotNull('user_id')->where('user_id', '!=', $request->user()->id)
            ->with('user:id,name')->first()?->user;
        if ($owner) {
            abort(403, "{$owner->name} saved toward this from their own wallet, so only {$owner->name} can delete it. You can cancel it instead.");
        }
        $goal->delete();

        return response()->json(null, 204);
    }

    public function contribute(Request $request, int $id): JsonResponse
    {
        $goal = $request->user()->couple->goals()->findOrFail($id);
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'decimal:0,2', 'gt:0', 'max:9999999999'],
            'wallet_id' => ['sometimes', 'nullable', 'integer'],
        ]);
        if ($goal->cancelled_at) {
            throw ValidationException::withMessages(['goal' => 'Restore this goal before adding to it.']);
        }
        $wallet = empty($data['wallet_id']) ? null : Wallet::usable($request->user()->couple, $data['wallet_id'], $request->user()->id);
        unset($data['wallet_id']);

        // Logged as a transfer so it shows in Activity and can be undone by deleting it.
        $transfer = DB::transaction(function () use ($request, $goal, $data, $wallet) {
            $transfer = $request->user()->couple->transactions()->create([
                'user_id' => $request->user()->id,
                'goal_id' => $goal->id,
                'wallet_id' => $wallet?->id,
                'type' => 'transfer',
                'amount' => $data['amount'],
                'category' => Transaction::TRANSFER_CATEGORY,
                'title' => "Transfer to {$goal->name}",
                'payment_method' => $wallet?->paymentMethod() ?? 'bank',
                'is_split' => false,
                'occurred_on' => CarbonImmutable::now()->toDateString(),
            ]);
            $goal->contributions()->create($data + ['user_id' => $request->user()->id, 'transaction_id' => $transfer->id]);

            return $transfer;
        });

        return response()->json(
            $this->present($goal->loadSum('contributions as saved', 'amount')) + ['transaction_id' => $transfer->id],
            201,
        );
    }

    /** Cancels a goal: it stays in history, and what was saved is released. */
    public function cancel(Request $request, int $id): JsonResponse
    {
        $goal = $request->user()->couple->goals()->withSum('contributions as saved', 'amount')->findOrFail($id);
        if ($goal->cancelled_at) {
            throw ValidationException::withMessages(['goal' => 'This goal is already cancelled.']);
        }

        DB::transaction(function () use ($request, $goal) {
            $goal->forceFill(['cancelled_at' => now()])->save();
            $saved = round((float) ($goal->saved ?? 0), 2);
            if ($saved > 0) {
                $request->user()->couple->transactions()->create([
                    'user_id' => $request->user()->id,
                    'goal_id' => $goal->id,
                    'type' => 'release',
                    'amount' => $saved,
                    'category' => Transaction::TRANSFER_CATEGORY,
                    'title' => "Released from {$goal->name}",
                    'payment_method' => 'bank',
                    'is_split' => false,
                    'occurred_on' => CarbonImmutable::now()->toDateString(),
                ]);
            }
        });

        return response()->json($this->present($goal));
    }

    /** Brings a cancelled goal back, with its savings set aside again. */
    public function restore(Request $request, int $id): JsonResponse
    {
        $couple = $request->user()->couple;
        $goal = $couple->goals()->findOrFail($id);

        DB::transaction(function () use ($couple, $goal) {
            $couple->transactions()->where('goal_id', $goal->id)->where('type', 'release')->delete();
            $goal->forceFill(['cancelled_at' => null])->save();
        });

        return response()->json($this->present($goal->loadSum('contributions as saved', 'amount')));
    }

    private function present(Goal $goal, ?\Illuminate\Support\Collection $contributorIds = null): array
    {
        $saved = (float) ($goal->saved ?? 0);

        return array_merge($goal->toArray(), [
            'saved' => $saved,
            'percent' => $goal->target_amount > 0 ? min(100, (int) round($saved / $goal->target_amount * 100)) : 0,
            'contributor_ids' => $contributorIds ?? $goal->contributions()->distinct()->pluck('user_id'),
        ]);
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $req = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$req, 'string', 'max:80'],
            'subtitle' => ['nullable', 'string', 'max:120'],
            'icon' => ['sometimes', 'string', 'max:30'],
            'target_amount' => [$req, 'numeric', 'decimal:0,2', 'gt:0', 'max:9999999999'],
            'target_date' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:2000-01-01', 'before:2100-01-01'],
        ]);
    }
}
