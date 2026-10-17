<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A transfer moves money into a goal: logged in Activity, never counted as spending.
        Schema::table('transactions', function (Blueprint $table) {
            $table->enum('type', ['expense', 'income', 'transfer'])->change();
            $table->foreignId('goal_id')->nullable()->after('user_id')->constrained()->cascadeOnDelete();
        });

        // The transfer behind a contribution, so deleting one removes the other.
        Schema::table('goal_contributions', function (Blueprint $table) {
            $table->foreignId('transaction_id')->nullable()->after('user_id')->constrained()->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('goal_contributions', function (Blueprint $table) {
            $table->dropConstrainedForeignId('transaction_id');
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->dropConstrainedForeignId('goal_id');
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->enum('type', ['expense', 'income'])->change();
        });
    }
};
