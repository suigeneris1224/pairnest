<?php

namespace App\Models;

use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    public const CATEGORIES = ['food', 'transport', 'bills', 'shopping', 'entertainment', 'health', 'others', 'income'];

    public const PAYMENT_METHODS = ['cash', 'card', 'gcash', 'maya', 'bank'];

    /** A release gives a cancelled goal's savings back; a move shifts money between two wallets. */
    public const TYPES = ['expense', 'income', 'transfer', 'release', 'move'];

    /** Set by the server on transfers into goals; not a category people pick. */
    public const TRANSFER_CATEGORY = 'savings';

    protected $fillable = ['user_id', 'goal_id', 'bill_id', 'wallet_id', 'to_wallet_id', 'move_id', 'type', 'amount', 'category', 'title', 'payment_method', 'is_split', 'occurred_on'];

    protected function casts(): array
    {
        return ['amount' => 'float', 'is_split' => 'boolean', 'occurred_on' => 'date:Y-m-d'];
    }

    /** Within $month's calendar month; a range, so the (couple_id, occurred_on) index is used. */
    public function scopeInMonth(Builder $query, CarbonImmutable $month): void
    {
        $query->whereBetween('occurred_on', [$month->startOfMonth()->toDateString(), $month->endOfMonth()->toDateString()]);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class);
    }

    public function toWallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class, 'to_wallet_id');
    }

    public function goal(): BelongsTo
    {
        return $this->belongsTo(Goal::class);
    }
}
