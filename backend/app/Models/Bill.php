<?php

namespace App\Models;

use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Bill extends Model
{
    public const FREQUENCIES = ['monthly', 'weekly'];

    protected $fillable = ['user_id', 'wallet_id', 'title', 'amount', 'category', 'frequency', 'next_due_on', 'anchor_day', 'is_split'];

    protected $hidden = ['anchor_day'];

    protected $attributes = ['frequency' => 'monthly', 'is_split' => true];

    protected function casts(): array
    {
        return ['amount' => 'float', 'is_split' => 'boolean', 'next_due_on' => 'date:Y-m-d', 'anchor_day' => 'integer'];
    }

    /** Moves the due date to the next period, returning to the anchor day where the month allows. */
    public function advance(): void
    {
        $due = CarbonImmutable::parse($this->next_due_on);

        if ($this->frequency === 'weekly') {
            $next = $due->addWeek();
        } else {
            $month = $due->startOfMonth()->addMonth();
            $next = $month->setDay(min($this->anchor_day, $month->daysInMonth));
        }

        $this->next_due_on = $next->toDateString();
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
