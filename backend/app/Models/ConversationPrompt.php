<?php

namespace App\Models;

use DateTimeInterface;
use Illuminate\Database\Eloquent\Model;

class ConversationPrompt extends Model
{
    public $timestamps = false;

    protected $fillable = ['topic', 'question'];

    /** Same prompt for both partners all week, rotating per couple. */
    public static function forWeek(Couple $couple, ?DateTimeInterface $date = null): ?self
    {
        $count = static::count();
        if ($count === 0) {
            return null;
        }
        $date ??= now();
        $index = ((int) $date->format('oW') + $couple->id) % $count;

        return static::orderBy('id')->skip($index)->first();
    }
}
