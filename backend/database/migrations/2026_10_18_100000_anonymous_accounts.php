<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Accounts are anonymous: a token on the phone, plus a recovery key we
        // only keep a hash of. No email, no password.
        Schema::table('users', function (Blueprint $table) {
            $table->string('email')->nullable()->change();
            $table->string('password')->nullable()->change();
            $table->string('recovery_key_hash', 64)->nullable()->unique()->after('name');
            // Onboarding answers: partner's name, stage, goals, money style, budget.
            $table->json('profile')->nullable()->after('recovery_key_hash');
        });

        Schema::table('couples', function (Blueprint $table) {
            $table->string('stage', 20)->nullable()->after('theme');
        });
    }

    public function down(): void
    {
        Schema::table('couples', function (Blueprint $table) {
            $table->dropColumn('stage');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['recovery_key_hash']);
            $table->dropColumn(['recovery_key_hash', 'profile']);
        });
    }
};
