<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MoodCheckin extends Model
{
    public const MOODS = ['happy', 'calm', 'anxious', 'stressed', 'tired'];

    protected $fillable = ['user_id', 'mood', 'note', 'is_private'];

    protected function casts(): array
    {
        return ['is_private' => 'boolean'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Own check-ins plus the partner's shared ones. */
    public function scopeVisibleTo(Builder $query, User $user): void
    {
        $query->where(fn (Builder $q) => $q
            ->where('user_id', $user->id)
            ->orWhere('is_private', false));
    }
}
