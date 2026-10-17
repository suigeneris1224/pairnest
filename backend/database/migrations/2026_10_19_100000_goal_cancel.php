<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A cancelled goal stays in history; its savings are released.
        Schema::table('goals', function (Blueprint $table) {
            $table->timestamp('cancelled_at')->nullable()->after('target_date');
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->enum('type', ['expense', 'income', 'transfer', 'release'])->change();
        });
    }

    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->enum('type', ['expense', 'income', 'transfer'])->change();
        });

        Schema::table('goals', function (Blueprint $table) {
            $table->dropColumn('cancelled_at');
        });
    }
};
