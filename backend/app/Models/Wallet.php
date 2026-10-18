<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class Wallet extends Model
{
    public const KINDS = ['cash', 'ewallet', 'debit', 'credit', 'bank'];

    /** Local banks and e-wallets; the app colours each card by its provider. */
    public const PROVIDERS = [
        'gcash', 'maya', 'grabpay', 'shopeepay', 'coins',
        'maribank', 'gotyme', 'tonik', 'uno', 'cimb', 'seabank',
        'bpi', 'bdo', 'metrobank', 'unionbank', 'securitybank', 'landbank', 'pnb', 'rcbc', 'chinabank', 'eastwest', 'psbank', 'aub',
        'cash', 'other',
    ];

    protected $fillable = ['user_id', 'name', 'kind', 'provider', 'last4', 'opening_balance', 'show_balance_to_partner', 'archived_at'];

    protected $hidden = ['opening_balance', 'couple_id'];

    protected function casts(): array
    {
        return [
            'opening_balance' => 'float',
            'show_balance_to_partner' => 'boolean',
            'archived_at' => 'datetime',
        ];
    }

    public function isShared(): bool
    {
        return $this->user_id === null;
    }

    /** Shared wallets and your own; never your partner's personal ones. */
    public function usableBy(int $userId): bool
    {
        return $this->user_id === null || $this->user_id === $userId;
    }

    /** The payment_method tag older clients and reports read. */
    public function paymentMethod(): string
    {
        return match (true) {
            in_array($this->provider, ['gcash', 'maya'], true) => $this->provider,
            $this->kind === 'cash' => 'cash',
            in_array($this->kind, ['debit', 'credit'], true) => 'card',
            default => 'bank',
        };
    }

    /**
     * Money in minus money out, per wallet id, from every transaction:
     * income and releases land in a wallet; expenses and goal transfers leave
     * it; a move leaves one wallet and lands in another.
     *
     * @return array<int, float>
     */
    public static function flows(int $coupleId): array
    {
        $out = DB::table('transactions')
            ->where('couple_id', $coupleId)->whereNotNull('wallet_id')
            ->groupBy('wallet_id')
            ->selectRaw("wallet_id as id, sum(case when type in ('income', 'release') then amount else -amount end) as net")
            ->pluck('net', 'id');
        $in = DB::table('transactions')
            ->where('couple_id', $coupleId)->where('type', 'move')->whereNotNull('to_wallet_id')
            ->groupBy('to_wallet_id')
            ->selectRaw('to_wallet_id as id, sum(amount) as net')
            ->pluck('net', 'id');

        $flows = [];
        foreach ([$out, $in] as $rows) {
            foreach ($rows as $id => $net) {
                $flows[$id] = round(($flows[$id] ?? 0) + (float) $net, 2);
            }
        }

        return $flows;
    }

    /** What the viewer may see of this wallet, with its balance or null when private. */
    public function presentFor(int $viewerId, array $flows): array
    {
        $visible = $this->usableBy($viewerId) || $this->show_balance_to_partner;

        return $this->toArray() + [
            'is_shared' => $this->isShared(),
            'balance' => $visible ? round($this->opening_balance + ($flows[$this->id] ?? 0), 2) : null,
        ];
    }

    /**
     * The active wallet $id in $couple that $userId may use (shared or their own),
     * or a validation error on $field.
     */
    public static function usable(Couple $couple, int $id, int $userId, string $field = 'wallet_id'): self
    {
        $wallet = $couple->wallets()->active()->find($id);
        if (! $wallet || ! $wallet->usableBy($userId)) {
            throw ValidationException::withMessages([$field => 'Pick one of your wallets or a shared one.']);
        }

        return $wallet;
    }

    public function scopeActive(Builder $query): void
    {
        $query->whereNull('archived_at');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
