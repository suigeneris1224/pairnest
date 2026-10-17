<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * An anonymous partner: a first name, onboarding answers and API tokens.
 * They get back in on a new phone with a recovery key (only its hash is kept)
 * or a re-link code from their partner.
 */
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    public const STAGES = ['dating', 'engaged', 'married', 'living_together'];

    public const MONEY_STYLES = ['shared', 'partly', 'separate'];

    /** Readable characters only: no 0/O, 1/I/L. */
    private const KEY_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    protected $fillable = [
        'name',
        'profile',
    ];

    protected $hidden = [
        'email',
        'password',
        'remember_token',
        'recovery_key_hash',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'profile' => 'array',
        ];
    }

    public function couple(): BelongsTo
    {
        return $this->belongsTo(Couple::class);
    }

    /** Random characters that are easy to read aloud and type. */
    public static function randomCode(int $length): string
    {
        $chars = '';
        for ($i = 0; $i < $length; $i++) {
            $chars .= self::KEY_ALPHABET[random_int(0, strlen(self::KEY_ALPHABET) - 1)];
        }

        return $chars;
    }

    /** A random key like "K7QM-2WXP-9DTR-H4NB" (about 79 bits). */
    public static function newRecoveryKey(): string
    {
        return implode('-', str_split(static::randomCode(16), 4));
    }

    /** Case and dashes don't matter when typing a key back in. */
    public static function hashRecoveryKey(string $key): string
    {
        return hash('sha256', strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $key)));
    }

    /** Issues a new recovery key (the old one stops working) and returns it once. */
    public function issueRecoveryKey(?string $key = null): string
    {
        $key ??= static::newRecoveryKey();
        $this->forceFill(['recovery_key_hash' => static::hashRecoveryKey($key)])->save();

        return $key;
    }
}
