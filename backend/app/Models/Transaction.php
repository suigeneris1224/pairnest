<?php

namespace App\Models;

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

    protected $fillable = ['user_id', 'goal_id', 'wallet_id', 'to_wallet_id', 'type', 'amount', 'category', 'title', 'payment_method', 'is_split', 'occurred_on'];

    protected function casts(): array
    {
        return ['amount' => 'float', 'is_split' => 'boolean', 'occurred_on' => 'date:Y-m-d'];
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
