<?php

namespace Database\Seeders;

use App\Models\Couple;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Alex & Sam from the design mockup. Local only: get in with the recovery
 * keys DEMO-ALEX-0000-NEST (Alex) or DEMO-SAMM-0000-NEST (Sam).
 */
class DemoCoupleSeeder extends Seeder
{
    public function run(): void
    {
        if (Couple::where('invite_code', 'NEST01')->exists()) {
            return;
        }

        $couple = Couple::create(['invite_code' => 'NEST01', 'theme' => 'sage', 'stage' => 'living_together']);
        $alex = User::factory()->for($couple)->create(['name' => 'Alex']);
        $sam = User::factory()->for($couple)->create(['name' => 'Sam']);
        $alex->issueRecoveryKey('DEMO-ALEX-0000-NEST');
        $sam->issueRecoveryKey('DEMO-SAMM-0000-NEST');
        $this->command?->info('Demo nest: recovery keys DEMO-ALEX-0000-NEST (Alex), DEMO-SAMM-0000-NEST (Sam).');

        $month = now()->startOfMonth();
        $budget = $couple->budgets()->create(['month' => $month->toDateString(), 'total' => 32000]);
        $budget->lines()->createMany([
            ['category' => 'food', 'limit_amount' => 8000],
            ['category' => 'bills', 'limit_amount' => 6000],
            ['category' => 'transport', 'limit_amount' => 4000],
            ['category' => 'shopping', 'limit_amount' => 4000],
            ['category' => 'entertainment', 'limit_amount' => 3000],
        ]);

        $day = fn (int $d) => $month->copy()->addDays($d - 1)->toDateString();
        $couple->transactions()->createMany([
            ['user_id' => $alex->id, 'type' => 'income', 'amount' => 45000, 'category' => 'income', 'title' => 'Salary', 'payment_method' => 'bank', 'occurred_on' => $day(1)],
            ['user_id' => $alex->id, 'type' => 'expense', 'amount' => 3800, 'category' => 'food', 'title' => 'Weekly groceries', 'payment_method' => 'card', 'is_split' => true, 'occurred_on' => $day(3)],
            ['user_id' => $sam->id, 'type' => 'expense', 'amount' => 3600, 'category' => 'bills', 'title' => 'Internet & water', 'payment_method' => 'gcash', 'is_split' => true, 'occurred_on' => $day(5)],
            ['user_id' => $sam->id, 'type' => 'expense', 'amount' => 2400, 'category' => 'transport', 'title' => 'Fuel', 'payment_method' => 'cash', 'occurred_on' => $day(6)],
            ['user_id' => $alex->id, 'type' => 'expense', 'amount' => 2500, 'category' => 'shopping', 'title' => 'Home essentials', 'payment_method' => 'card', 'occurred_on' => $day(7)],
            ['user_id' => $sam->id, 'type' => 'expense', 'amount' => 1800, 'category' => 'entertainment', 'title' => 'Date night', 'payment_method' => 'card', 'is_split' => true, 'occurred_on' => $day(8)],
            ['user_id' => $alex->id, 'type' => 'expense', 'amount' => 2430, 'category' => 'bills', 'title' => 'Electricity bill', 'payment_method' => 'gcash', 'is_split' => true, 'occurred_on' => $day(9)],
            ['user_id' => $sam->id, 'type' => 'expense', 'amount' => 1250, 'category' => 'food', 'title' => 'Groceries', 'payment_method' => 'cash', 'occurred_on' => $day(10)],
        ]);

        $japan = $couple->goals()->create(['name' => 'Japan Trip', 'subtitle' => 'Travel & Experience', 'icon' => 'travel', 'target_amount' => 80000, 'target_date' => $month->copy()->addMonths(7)->toDateString()]);
        $japan->contributions()->createMany([['user_id' => $alex->id, 'amount' => 7000], ['user_id' => $sam->id, 'amount' => 5000]]);
        $fund = $couple->goals()->create(['name' => 'Emergency Fund', 'subtitle' => 'Safety & Security', 'icon' => 'shield', 'target_amount' => 50000, 'target_date' => $month->copy()->addMonths(7)->toDateString()]);
        $fund->contributions()->createMany([['user_id' => $alex->id, 'amount' => 8000], ['user_id' => $sam->id, 'amount' => 7000]]);
        $home = $couple->goals()->create(['name' => 'New Home', 'subtitle' => 'Home', 'icon' => 'home', 'target_amount' => 2000000]);
        $home->contributions()->create(['user_id' => $alex->id, 'amount' => 160000]);

        $couple->moods()->createMany([
            ['user_id' => $alex->id, 'mood' => 'calm', 'note' => 'Feeling good about our progress! Let\'s keep it up!'],
            ['user_id' => $sam->id, 'mood' => 'happy', 'note' => 'Date night and a productive budget talk. Feeling grateful.'],
            ['user_id' => $sam->id, 'mood' => 'tired', 'note' => 'Long week at work.', 'is_private' => true],
        ]);

        $today = now('Asia/Manila')->startOfDay();
        foreach ([
            ['user_id' => $alex->id, 'title' => 'Rent', 'amount' => 15000, 'category' => 'bills', 'next_due_on' => $today->copy()->addDays(3)],
            ['user_id' => $sam->id, 'title' => 'Netflix', 'amount' => 549, 'category' => 'entertainment', 'next_due_on' => $today->copy()->addDays(6)],
            ['user_id' => $alex->id, 'title' => 'Meralco', 'amount' => 2600, 'category' => 'bills', 'next_due_on' => $today->copy()->addDays(12)],
        ] as $bill) {
            $couple->bills()->create(['next_due_on' => $bill['next_due_on']->toDateString(), 'anchor_day' => $bill['next_due_on']->day] + $bill);
        }

        $couple->plans()->createMany([
            ['kind' => 'date', 'title' => 'Date Night', 'notes' => 'Dinner by the bay', 'scheduled_at' => now('Asia/Manila')->addDays(2)->setTime(19, 0)->utc()],
            ['kind' => 'life', 'title' => 'Japan Trip', 'goal_id' => $japan->id, 'scheduled_at' => $month->copy()->addMonths(7)],
            ['kind' => 'life', 'title' => 'New Home', 'goal_id' => $home->id],
            ['kind' => 'date', 'title' => 'Anniversary', 'scheduled_at' => now('Asia/Manila')->addMonths(1)->setTime(18, 0)->utc()],
        ]);
    }
}
