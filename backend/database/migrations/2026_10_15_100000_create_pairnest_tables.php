<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('couples', function (Blueprint $table) {
            $table->id();
            $table->string('invite_code', 8)->unique();
            $table->string('theme', 20)->default('sage');
            $table->timestamps();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->foreignId('couple_id')->nullable()->after('id')->constrained()->nullOnDelete();
        });

        Schema::create('budgets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            $table->date('month');
            $table->decimal('total', 12, 2);
            $table->timestamps();
            $table->unique(['couple_id', 'month']);
        });

        Schema::create('budget_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('budget_id')->constrained()->cascadeOnDelete();
            $table->string('category', 30);
            $table->decimal('limit_amount', 12, 2);
            $table->unique(['budget_id', 'category']);
        });

        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('type', ['expense', 'income']);
            $table->decimal('amount', 12, 2);
            $table->string('category', 30);
            $table->string('title');
            $table->string('payment_method', 30)->default('cash');
            $table->boolean('is_split')->default(false);
            $table->date('occurred_on');
            $table->timestamps();
            $table->index(['couple_id', 'occurred_on']);
        });

        Schema::create('goals', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('subtitle')->nullable();
            $table->string('icon', 30)->default('star');
            $table->decimal('target_amount', 12, 2);
            $table->date('target_date')->nullable();
            $table->timestamps();
        });

        Schema::create('goal_contributions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('goal_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->decimal('amount', 12, 2);
            $table->timestamps();
        });

        Schema::create('mood_checkins', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('mood', ['happy', 'calm', 'anxious', 'stressed', 'tired']);
            $table->text('note')->nullable();
            $table->boolean('is_private')->default(false);
            $table->timestamps();
            $table->index(['couple_id', 'created_at']);
        });

        Schema::create('conversation_prompts', function (Blueprint $table) {
            $table->id();
            $table->string('topic', 30);
            $table->string('question');
        });

        Schema::create('conversation_answers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_prompt_id')->constrained()->cascadeOnDelete();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('answer');
            $table->timestamps();
            $table->unique(['conversation_prompt_id', 'user_id']);
        });

        Schema::create('plans', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            $table->foreignId('goal_id')->nullable()->constrained()->nullOnDelete();
            $table->enum('kind', ['date', 'life']);
            $table->string('title');
            $table->text('notes')->nullable();
            $table->dateTime('scheduled_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('plans');
        Schema::dropIfExists('conversation_answers');
        Schema::dropIfExists('conversation_prompts');
        Schema::dropIfExists('mood_checkins');
        Schema::dropIfExists('goal_contributions');
        Schema::dropIfExists('goals');
        Schema::dropIfExists('transactions');
        Schema::dropIfExists('budget_lines');
        Schema::dropIfExists('budgets');
        Schema::table('users', function (Blueprint $table) {
            $table->dropConstrainedForeignId('couple_id');
        });
        Schema::dropIfExists('couples');
    }
};
