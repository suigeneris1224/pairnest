<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BudgetLine extends Model
{
    public $timestamps = false;

    protected $fillable = ['category', 'limit_amount'];

    protected function casts(): array
    {
        return ['limit_amount' => 'float'];
    }
}
