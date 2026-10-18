<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Settlement extends Model
{
    protected $fillable = ['from_user_id', 'to_user_id', 'from_wallet_id', 'to_wallet_id', 'amount', 'settled_on'];

    protected function casts(): array
    {
        return ['amount' => 'float', 'settled_on' => 'date:Y-m-d'];
    }

    public function from(): BelongsTo
    {
        return $this->belongsTo(User::class, 'from_user_id');
    }

    public function to(): BelongsTo
    {
        return $this->belongsTo(User::class, 'to_user_id');
    }

    public function fromWallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class, 'from_wallet_id');
    }

    public function toWallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class, 'to_wallet_id');
    }

    /** What a settlement response loads: who paid whom, and from and to which wallets. */
    public const WITH = ['from:id,name', 'to:id,name', 'fromWallet:id,name', 'toWallet:id,name'];
}
