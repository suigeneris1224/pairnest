<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Goal extends Model
{
    protected $fillable = ['name', 'subtitle', 'icon', 'target_amount', 'target_date'];

    protected $appends = ['cancelled'];

    protected function casts(): array
    {
        return ['target_amount' => 'float', 'target_date' => 'date:Y-m-d', 'cancelled_at' => 'datetime'];
    }

    /** Cancelled goals stay in history with their savings released. */
    public function getCancelledAttribute(): bool
    {
        return $this->cancelled_at !== null;
    }

    public function contributions(): HasMany
    {
        return $this->hasMany(GoalContribution::class);
    }
}
