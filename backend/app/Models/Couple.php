<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Couple extends Model
{
    public const THEMES = ['sage', 'ocean', 'lavender', 'peach', 'midnight'];

    public const MAX_MEMBERS = 2;

    protected $fillable = ['invite_code', 'theme', 'stage'];

    protected static function booted(): void
    {
        static::creating(function (Couple $couple) {
            $couple->invite_code ??= static::uniqueInviteCode();
        });
    }

    public static function uniqueInviteCode(): string
    {
        do {
            $code = Str::upper(Str::random(6));
        } while (static::where('invite_code', $code)->exists());

        return $code;
    }

    public function members(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function budgets(): HasMany
    {
        return $this->hasMany(Budget::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    public function goals(): HasMany
    {
        return $this->hasMany(Goal::class);
    }

    public function moods(): HasMany
    {
        return $this->hasMany(MoodCheckin::class);
    }

    public function bills(): HasMany
    {
        return $this->hasMany(Bill::class);
    }

    public function settlements(): HasMany
    {
        return $this->hasMany(Settlement::class);
    }

    public function plans(): HasMany
    {
        return $this->hasMany(Plan::class);
    }

    public function answers(): HasMany
    {
        return $this->hasMany(ConversationAnswer::class);
    }
}
