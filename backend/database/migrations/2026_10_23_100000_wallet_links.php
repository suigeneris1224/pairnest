<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Where a payday lands and which wallet usually pays a bill.
        foreach (['paydays', 'bills'] as $name) {
            Schema::table($name, function (Blueprint $table) {
                $table->foreignId('wallet_id')->nullable()->after('user_id')->constrained()->nullOnDelete();
            });
        }
    }

    public function down(): void
    {
        foreach (['paydays', 'bills'] as $name) {
            Schema::table($name, function (Blueprint $table) {
                $table->dropConstrainedForeignId('wallet_id');
            });
        }
    }
};
