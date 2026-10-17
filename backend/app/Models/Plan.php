<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Plan extends Model
{
    protected $fillable = ['kind', 'title', 'notes', 'scheduled_at', 'goal_id'];

    protected function casts(): array
    {
        return ['scheduled_at' => 'datetime'];
    }

    public function goal(): BelongsTo
    {
        return $this->belongsTo(Goal::class);
    }
}
