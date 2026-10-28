<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * SQLite doesn't index foreign keys on its own, so every lookup, cascade and
 * null-on-delete through them scanned the whole table.
 */
return new class extends Migration
{
    private const INDEXES = [
        'transactions' => ['move_id', 'wallet_id', 'to_wallet_id', 'goal_id', ['couple_id', 'type', 'occurred_on']],
        'users' => ['couple_id'],
        'goals' => ['couple_id'],
        'goal_contributions' => ['goal_id', 'transaction_id'],
        'plans' => ['couple_id'],
        'conversation_answers' => ['couple_id'],
        'settlements' => ['from_wallet_id', 'to_wallet_id'],
        'bills' => ['wallet_id'],
        'paydays' => ['wallet_id'],
    ];

    public function up(): void
    {
        foreach (self::INDEXES as $table => $indexes) {
            Schema::table($table, function (Blueprint $t) use ($indexes) {
                foreach ($indexes as $columns) {
                    $t->index($columns);
                }
            });
        }
    }

    public function down(): void
    {
        foreach (self::INDEXES as $table => $indexes) {
            Schema::table($table, function (Blueprint $t) use ($indexes) {
                foreach ($indexes as $columns) {
                    $t->dropIndex((array) $columns);
                }
            });
        }
    }
};
