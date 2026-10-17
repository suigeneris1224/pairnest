<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('bills', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title');
            $table->decimal('amount', 12, 2);
            $table->string('category', 20);
            $table->enum('frequency', ['monthly', 'weekly'])->default('monthly');
            $table->date('next_due_on');
            // Day of month the bill is meant to fall on, so a 31st bill comes back
            // to the 31st after being clamped to a shorter month.
            $table->unsignedTinyInteger('anchor_day');
            $table->boolean('is_split')->default(true);
            $table->timestamps();
            $table->index(['couple_id', 'next_due_on']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('bills');
    }
};
