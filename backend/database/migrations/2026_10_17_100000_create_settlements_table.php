<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // One partner paying the other back for shared expenses.
        Schema::create('settlements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            $table->foreignId('from_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('to_user_id')->constrained('users')->cascadeOnDelete();
            $table->decimal('amount', 12, 2);
            $table->date('settled_on');
            $table->timestamps();
            $table->index(['couple_id', 'settled_on']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('settlements');
    }
};
