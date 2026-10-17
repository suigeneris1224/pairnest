<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Budget extends Model
{
    protected $fillable = ['month', 'total'];

    protected function casts(): array
    {
        return ['month' => 'date:Y-m-d', 'total' => 'float'];
    }

    public function lines(): HasMany
    {
        return $this->hasMany(BudgetLine::class)->orderBy('id');
    }
}
