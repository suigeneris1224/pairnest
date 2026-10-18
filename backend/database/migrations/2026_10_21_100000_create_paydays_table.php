<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('paydays', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            // Whose pay it is; only they can change or log it.
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title')->default('Salary');
            $table->decimal('amount', 12, 2);
            $table->enum('frequency', ['semimonthly', 'monthly', 'biweekly', 'weekly'])->default('semimonthly');
            $table->date('next_on');
            // Days of the month for monthly (day_a) and twice-a-month (day_a < day_b) pay.
            $table->unsignedTinyInteger('day_a')->nullable();
            $table->unsignedTinyInteger('day_b')->nullable();
            $table->boolean('is_split')->default(true);
            $table->timestamps();
            $table->index(['couple_id', 'next_on']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('paydays');
    }
};
