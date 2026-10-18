<?php

use Carbon\CarbonImmutable;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A fee charged on a move (InstaPay, ATM) is an expense tied to it.
        Schema::table('transactions', function (Blueprint $table) {
            $table->foreignId('move_id')->nullable()->after('to_wallet_id')->constrained('transactions')->cascadeOnDelete();
        });

        // Everyone gets a Cash wallet that can't be removed.
        Schema::table('wallets', function (Blueprint $table) {
            $table->boolean('builtin')->default(false)->after('show_balance_to_partner');
        });

        // Paying a partner back can come out of one wallet and land in another.
        Schema::table('settlements', function (Blueprint $table) {
            $table->foreignId('from_wallet_id')->nullable()->after('to_user_id')->constrained('wallets')->nullOnDelete();
            $table->foreignId('to_wallet_id')->nullable()->after('from_wallet_id')->constrained('wallets')->nullOnDelete();
        });

        $now = CarbonImmutable::now();
        $users = DB::table('users')->whereNotNull('couple_id')->get(['id', 'couple_id']);
        foreach ($users as $user) {
            DB::table('wallets')->insert([
                'couple_id' => $user->couple_id,
                'user_id' => $user->id,
                'name' => 'Cash',
                'kind' => 'cash',
                'provider' => 'cash',
                'opening_balance' => 0,
                'show_balance_to_partner' => false,
                'builtin' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        DB::table('wallets')->where('builtin', true)
            ->whereNotExists(fn ($q) => $q->from('transactions')->whereColumn('transactions.wallet_id', 'wallets.id')
                ->orWhereColumn('transactions.to_wallet_id', 'wallets.id'))
            ->delete();
        Schema::table('settlements', function (Blueprint $table) {
            $table->dropConstrainedForeignId('to_wallet_id');
            $table->dropConstrainedForeignId('from_wallet_id');
        });
        Schema::table('wallets', function (Blueprint $table) {
            $table->dropColumn('builtin');
        });
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropConstrainedForeignId('move_id');
        });
    }
};
