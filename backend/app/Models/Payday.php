<?php

namespace App\Models;

use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payday extends Model
{
    public const FREQUENCIES = ['semimonthly', 'monthly', 'biweekly', 'weekly'];

    /** Frequencies set by days of the month rather than a start date. */
    public const BY_DAY = ['semimonthly', 'monthly'];

    protected $fillable = ['user_id', 'wallet_id', 'title', 'amount', 'frequency', 'next_on', 'day_a', 'day_b', 'is_split'];

    protected $hidden = ['day_a', 'day_b'];

    protected $appends = ['days'];

    protected $attributes = ['title' => 'Salary', 'frequency' => 'semimonthly', 'is_split' => true];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'is_split' => 'boolean',
            'next_on' => 'date:Y-m-d',
            'day_a' => 'integer',
            'day_b' => 'integer',
        ];
    }

    /** @return list<int> the paydays' days of the month, e.g. [15, 30]; empty for weekly pay. */
    public function getDaysAttribute(): array
    {
        return array_values(array_filter([$this->day_a, $this->day_b]));
    }

    /** Moves to the following payday; short months use their last day. */
    public function advance(): void
    {
        $on = CarbonImmutable::parse($this->next_on);

        $next = match ($this->frequency) {
            'weekly' => $on->addWeek(),
            'biweekly' => $on->addWeeks(2),
            'monthly' => self::onDay($on->startOfMonth()->addMonth(), $this->day_a),
            default => $on->day < self::onDay($on, $this->day_b)->day
                ? self::onDay($on, $this->day_b)
                : self::onDay($on->startOfMonth()->addMonth(), $this->day_a),
        };

        $this->next_on = $next->toDateString();
    }

    /** The first payday on or after $today for a monthly or twice-a-month schedule. */
    public static function firstOnOrAfter(array $days, CarbonImmutable $today): CarbonImmutable
    {
        sort($days);
        $month = $today->startOfMonth();
        foreach ([$month, $month->addMonth()] as $m) {
            foreach ($days as $day) {
                $candidate = self::onDay($m, $day);
                if ($candidate->gte($today->startOfDay())) {
                    return $candidate;
                }
            }
        }

        return self::onDay($month->addMonth(), $days[0]);
    }

    private static function onDay(CarbonImmutable $month, int $day): CarbonImmutable
    {
        return $month->startOfMonth()->setDay(min($day, $month->daysInMonth));
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
