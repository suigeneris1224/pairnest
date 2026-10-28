<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Which bill an expense paid, so undoing a payment removes exactly that one.
        Schema::table('transactions', function (Blueprint $table) {
            $table->foreignId('bill_id')->nullable()->after('goal_id')->constrained()->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropConstrainedForeignId('bill_id');
        });
    }
};
