<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wallets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            // Null for a shared ("Ours") wallet.
            $table->foreignId('user_id')->nullable()->constrained()->cascadeOnDelete();
            $table->string('name', 60);
            $table->enum('kind', ['cash', 'ewallet', 'debit', 'credit', 'bank']);
            $table->string('provider', 30)->default('other');
            // Display only; a full card number is never stored.
            $table->string('last4', 4)->nullable();
            // Balance = opening_balance + money in − money out. Correcting a
            // balance rewrites this, so no adjustment rows are needed.
            $table->decimal('opening_balance', 12, 2)->default(0);
            $table->boolean('show_balance_to_partner')->default(false);
            $table->timestamp('archived_at')->nullable();
            $table->timestamps();
            $table->index(['couple_id', 'archived_at']);
        });

        // A move shifts money between two wallets: not spending, not income.
        Schema::table('transactions', function (Blueprint $table) {
            $table->enum('type', ['expense', 'income', 'transfer', 'release', 'move'])->change();
            $table->foreignId('wallet_id')->nullable()->after('goal_id')->constrained()->nullOnDelete();
            $table->foreignId('to_wallet_id')->nullable()->after('wallet_id')->constrained('wallets')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropConstrainedForeignId('to_wallet_id');
            $table->dropConstrainedForeignId('wallet_id');
        });
        Schema::table('transactions', function (Blueprint $table) {
            $table->enum('type', ['expense', 'income', 'transfer', 'release'])->change();
        });
        Schema::dropIfExists('wallets');
    }
};
