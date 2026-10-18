<?php

namespace Tests\Feature;

use App\Models\Couple;
use App\Models\User;
use Database\Seeders\ConversationPromptSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PairnestApiTest extends TestCase
{
    use RefreshDatabase;

    private function pair(): array
    {
        $couple = Couple::create();
        $alex = User::factory()->for($couple)->create(['name' => 'Alex']);
        $sam = User::factory()->for($couple)->create(['name' => 'Sam']);

        return [$couple, $alex, $sam];
    }

    /** Onboarding without email: returns [token, recovery key, user id]. */
    private function start(string $name, array $profile = []): array
    {
        $this->app['auth']->forgetGuards();
        $res = $this->postJson('/api/v1/auth/start', ['name' => $name] + ($profile ? ['profile' => $profile] : []))->assertCreated();

        return [$res->json('token'), $res->json('recovery_key'), $res->json('user.id')];
    }

    private function as(string $token): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($token);
    }

    public function test_onboarding_creates_an_anonymous_nest_from_your_answers(): void
    {
        [$alexToken, $key] = $this->start('Alex', [
            'partner_name' => 'Sam',
            'stage' => 'married',
            'financial_goals' => ['emergency', 'travel', 'wedding'],
            'family_goals' => ['getting_married', 'kids'],
            'money_style' => 'partly',
            'monthly_budget' => 30000,
        ]);
        $this->assertMatchesRegularExpression('/^[A-Z2-9]{4}(-[A-Z2-9]{4}){3}$/', $key);
        $alex = User::where('name', 'Alex')->first();
        $this->assertNull($alex->email);
        $this->assertNull($alex->password);
        $this->assertSame('Sam', $alex->profile['partner_name']);

        $code = $this->as($alexToken)->postJson('/api/v1/couple', ['theme' => 'lavender'])
            ->assertCreated()
            ->assertJsonPath('couple.stage', 'married')
            ->assertJsonMissingPath('couple.members.0.email')
            ->json('couple.invite_code');
        $this->as($alexToken)->getJson('/api/v1/goals')->assertJsonCount(4);
        $this->as($alexToken)->getJson('/api/v1/budgets/'.now()->format('Y-m'))->assertJsonPath('total', 30000);

        // Sam's picks add only goals the nest doesn't have.
        [$samToken] = $this->start('Sam', ['financial_goals' => ['travel', 'home'], 'family_goals' => ['pet']]);
        $this->as($samToken)->postJson('/api/v1/couple/join', ['code' => strtolower($code)])
            ->assertOk()
            ->assertJsonCount(2, 'couple.members');
        $names = collect($this->as($samToken)->getJson('/api/v1/goals')->json())->pluck('name')->sort()->values()->all();
        $this->assertSame(['Baby Fund', 'Emergency Fund', 'Our Home', 'Our Wedding', 'Pet Fund', 'Travel Fund'], $names);
        $this->as($samToken)->getJson('/api/v1/budgets/'.now()->format('Y-m'))->assertJsonPath('total', 30000);

        [$thirdToken] = $this->start('Third');
        $this->as($thirdToken)->postJson('/api/v1/couple/join', ['code' => $code])->assertUnprocessable();

        $this->postJson('/api/v1/auth/start', ['name' => 'X', 'profile' => ['financial_goals' => ['yacht']]])->assertUnprocessable();
        $this->postJson('/api/v1/auth/start', ['email' => 'a@b.c'])->assertUnprocessable();
    }

    public function test_a_recovery_key_brings_you_back_and_signs_out_the_old_phone(): void
    {
        [$oldToken, $key] = $this->start('Alex');
        $this->as($oldToken)->getJson('/api/v1/auth/me')->assertOk();

        $this->as('')->postJson('/api/v1/auth/recover', ['recovery_key' => 'AAAA-BBBB-CCCC-DDDD'])->assertUnprocessable();
        $newToken = $this->as('')->postJson('/api/v1/auth/recover', ['recovery_key' => strtolower(str_replace('-', ' ', $key))])
            ->assertOk()
            ->assertJsonPath('user.name', 'Alex')
            ->json('token');

        $this->as($oldToken)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->as($newToken)->getJson('/api/v1/auth/me')->assertOk();

        // A new key replaces the old one.
        $fresh = $this->as($newToken)->postJson('/api/v1/auth/recovery-key')->assertCreated()->json('recovery_key');
        $this->assertNotSame($key, $fresh);
        $this->as('')->postJson('/api/v1/auth/recover', ['recovery_key' => $key])->assertUnprocessable();
        $this->as('')->postJson('/api/v1/auth/recover', ['recovery_key' => $fresh])->assertOk();
    }

    public function test_a_partner_can_relink_a_lost_phone_once(): void
    {
        [$alexToken] = $this->start('Alex');
        $code = $this->as($alexToken)->postJson('/api/v1/couple')->json('couple.invite_code');

        $this->as($alexToken)->postJson('/api/v1/auth/relink')->assertUnprocessable();

        [$samToken] = $this->start('Sam');
        $this->as($samToken)->postJson('/api/v1/couple/join', ['code' => $code])->assertOk();

        $relink = $this->as($samToken)->postJson('/api/v1/auth/relink')
            ->assertCreated()
            ->assertJsonPath('for', 'Alex')
            ->json('code');
        $this->assertMatchesRegularExpression('/^[A-Z2-9]{8}$/', $relink);

        $newToken = $this->as('')->postJson('/api/v1/auth/relink/redeem', ['code' => strtolower($relink)])
            ->assertOk()
            ->assertJsonPath('user.name', 'Alex')
            ->assertJsonPath('user.couple.invite_code', $code)
            ->json('token');
        $this->as($alexToken)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->as($newToken)->getJson('/api/v1/dashboard')->assertOk();

        $this->as('')->postJson('/api/v1/auth/relink/redeem', ['code' => $relink])->assertUnprocessable();
    }

    public function test_couple_routes_require_a_nest(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/dashboard')->assertStatus(409);
    }

    public function test_budget_summary_counts_only_expenses_in_month(): void
    {
        [, $alex] = $this->pair();
        Sanctum::actingAs($alex);

        $this->putJson('/api/v1/budgets/2025-05', [
            'total' => 32000,
            'lines' => [['category' => 'food', 'limit_amount' => 8000]],
        ])->assertOk();

        foreach ([
            ['type' => 'expense', 'amount' => 1250, 'category' => 'food', 'occurred_on' => '2025-05-10'],
            ['type' => 'expense', 'amount' => 2430, 'category' => 'bills', 'occurred_on' => '2025-05-09'],
            ['type' => 'income', 'amount' => 40000, 'category' => 'income', 'occurred_on' => '2025-05-01'],
            ['type' => 'expense', 'amount' => 999, 'category' => 'food', 'occurred_on' => '2025-06-01'],
        ] as $tx) {
            $this->postJson('/api/v1/transactions', $tx + ['title' => 'x'])->assertCreated();
        }

        $this->getJson('/api/v1/budgets/2025-05')
            ->assertOk()
            ->assertJsonPath('spent', 3680)
            ->assertJsonPath('remaining', 28320)
            ->assertJsonPath('lines.0.spent', 1250)
            ->assertJsonPath('lines.0.percent', 16);
    }

    public function test_couples_cannot_see_each_others_data(): void
    {
        [, $alex] = $this->pair();
        [, $other] = $this->pair();

        Sanctum::actingAs($other);
        $id = $this->postJson('/api/v1/transactions', [
            'type' => 'expense', 'amount' => 100, 'category' => 'food', 'title' => 'Secret', 'occurred_on' => '2025-05-01',
        ])->json('id');

        Sanctum::actingAs($alex);
        $this->getJson('/api/v1/transactions')->assertJsonCount(0, 'data');
        $this->deleteJson("/api/v1/transactions/{$id}")->assertNotFound();
    }

    public function test_private_moods_are_hidden_from_partner(): void
    {
        [, $alex, $sam] = $this->pair();

        Sanctum::actingAs($sam);
        $this->postJson('/api/v1/moods', ['mood' => 'tired', 'is_private' => true])->assertCreated();
        $this->postJson('/api/v1/moods', ['mood' => 'happy'])->assertCreated();
        $this->getJson('/api/v1/moods')->assertJsonCount(2);

        Sanctum::actingAs($alex);
        $this->getJson('/api/v1/moods')->assertJsonCount(1)->assertJsonPath('0.mood', 'happy');
    }

    public function test_partner_answer_revealed_after_answering(): void
    {
        $this->seed(ConversationPromptSeeder::class);
        [, $alex, $sam] = $this->pair();

        Sanctum::actingAs($sam);
        $this->postJson('/api/v1/talks/current/answer', ['answer' => 'A trip to Japan'])
            ->assertOk()->assertJsonPath('answered', true);

        Sanctum::actingAs($alex);
        $this->getJson('/api/v1/talks/current')->assertJsonPath('answered', false)->assertJsonCount(0, 'answers');
        $this->postJson('/api/v1/talks/current/answer', ['answer' => 'A new couch'])->assertJsonCount(2, 'answers');
    }

    public function test_dashboard_reports_spending_by_category_and_last_month(): void
    {
        [, $alex] = $this->pair();
        Sanctum::actingAs($alex);
        $now = now();
        $lastMonth = now()->startOfMonth()->subMonth();

        foreach ([
            ['amount' => 1200, 'category' => 'food', 'occurred_on' => $now->toDateString()],
            ['amount' => 300, 'category' => 'food', 'occurred_on' => $now->toDateString()],
            ['amount' => 800, 'category' => 'transport', 'occurred_on' => $now->toDateString()],
            ['amount' => 2000, 'category' => 'bills', 'occurred_on' => $lastMonth->toDateString()],
        ] as $tx) {
            $this->postJson('/api/v1/transactions', $tx + ['type' => 'expense', 'title' => 'x'])->assertCreated();
        }

        $this->getJson('/api/v1/dashboard')
            ->assertOk()
            ->assertJsonPath('spending.food', 1500)
            ->assertJsonPath('spending.transport', 800)
            ->assertJsonMissingPath('spending.bills')
            ->assertJsonPath('last_month_spent', 2000);
    }

    public function test_feed_shows_partner_activity_but_not_mine_or_private(): void
    {
        $this->seed(ConversationPromptSeeder::class);
        [, $alex, $sam] = $this->pair();

        Sanctum::actingAs($alex);
        $this->postJson('/api/v1/transactions', [
            'type' => 'expense', 'amount' => 99, 'category' => 'food', 'title' => 'Mine', 'occurred_on' => now()->toDateString(),
        ])->assertCreated();
        $goal = $this->postJson('/api/v1/goals', ['name' => 'Japan Trip', 'target_amount' => 80000])->json('id');

        Sanctum::actingAs($sam);
        $this->postJson('/api/v1/transactions', [
            'type' => 'expense', 'amount' => 1250, 'category' => 'food', 'title' => 'Groceries', 'occurred_on' => now()->toDateString(),
        ])->assertCreated();
        $this->postJson("/api/v1/goals/{$goal}/contributions", ['amount' => 5000])->assertCreated();
        $this->postJson('/api/v1/moods', ['mood' => 'tired', 'is_private' => true])->assertCreated();
        $this->postJson('/api/v1/moods', ['mood' => 'happy'])->assertCreated();
        $this->postJson('/api/v1/talks/current/answer', ['answer' => 'Japan'])->assertOk();

        Sanctum::actingAs($alex);
        $feed = $this->getJson('/api/v1/feed')->assertOk()->json();

        $this->assertEqualsCanonicalizing(['expense', 'goal', 'mood', 'talk'], array_column($feed, 'type'));
        $this->assertSame(['Sam'], array_values(array_unique(array_column($feed, 'user_name'))));
        $this->assertStringContainsString('happy', collect($feed)->firstWhere('type', 'mood')['title']);
        $this->assertSame(1250.0, (float) collect($feed)->firstWhere('type', 'expense')['amount']);
    }

    public function test_transactions_can_be_edited_only_within_the_couple(): void
    {
        [, $alex, $sam] = $this->pair();
        [, $other] = $this->pair();

        Sanctum::actingAs($alex);
        $id = $this->postJson('/api/v1/transactions', [
            'type' => 'expense', 'amount' => 100, 'category' => 'food', 'title' => 'Lunch', 'occurred_on' => '2025-05-01',
        ])->json('id');

        Sanctum::actingAs($sam);
        $this->patchJson("/api/v1/transactions/{$id}", ['amount' => 180, 'category' => 'shopping'])
            ->assertOk()
            ->assertJsonPath('amount', 180)
            ->assertJsonPath('category', 'shopping')
            ->assertJsonPath('title', 'Lunch')
            ->assertJsonPath('user.name', 'Alex');

        Sanctum::actingAs($other);
        $this->patchJson("/api/v1/transactions/{$id}", ['amount' => 1])->assertNotFound();
    }

    public function test_paying_a_bill_records_an_expense_and_advances_the_due_date(): void
    {
        [, $alex, $sam] = $this->pair();
        Sanctum::actingAs($alex);

        $id = $this->postJson('/api/v1/bills', [
            'title' => 'Rent', 'amount' => 15000, 'category' => 'bills', 'next_due_on' => '2028-01-31',
        ])->assertCreated()->assertJsonPath('frequency', 'monthly')->assertJsonMissingPath('anchor_day')->json('id');

        Sanctum::actingAs($sam);
        $this->postJson("/api/v1/bills/{$id}/pay")
            ->assertCreated()
            ->assertJsonPath('bill.next_due_on', '2028-02-29')
            ->assertJsonPath('transaction.amount', 15000)
            ->assertJsonPath('transaction.title', 'Rent')
            ->assertJsonPath('transaction.user.name', 'Sam');
        // Back to the 31st once the month has one.
        $this->postJson("/api/v1/bills/{$id}/pay")->assertJsonPath('bill.next_due_on', '2028-03-31');
        $this->getJson('/api/v1/transactions')->assertJsonCount(2, 'data');

        $weekly = $this->postJson('/api/v1/bills', [
            'title' => 'Laundry', 'amount' => 300, 'category' => 'others', 'frequency' => 'weekly', 'next_due_on' => '2028-01-31',
        ])->json('id');
        $this->postJson("/api/v1/bills/{$weekly}/pay")->assertJsonPath('bill.next_due_on', '2028-02-07');

        $this->postJson('/api/v1/bills', [
            'title' => 'Bonus', 'amount' => 1, 'category' => 'income', 'next_due_on' => '2028-01-31',
        ])->assertUnprocessable();
    }

    public function test_bills_are_private_to_the_couple(): void
    {
        [, $alex] = $this->pair();
        [, $other] = $this->pair();

        Sanctum::actingAs($other);
        $id = $this->postJson('/api/v1/bills', [
            'title' => 'Secret', 'amount' => 100, 'category' => 'bills', 'next_due_on' => '2028-01-01',
        ])->json('id');

        Sanctum::actingAs($alex);
        $this->getJson('/api/v1/bills')->assertOk()->assertJsonCount(0);
        $this->patchJson("/api/v1/bills/{$id}", ['amount' => 1])->assertNotFound();
        $this->postJson("/api/v1/bills/{$id}/pay")->assertNotFound();
        $this->deleteJson("/api/v1/bills/{$id}")->assertNotFound();
    }

    public function test_dashboard_lists_bills_due_within_two_weeks(): void
    {
        [, $alex] = $this->pair();
        Sanctum::actingAs($alex);

        $this->travelTo(now()->setDate(2028, 3, 10));
        foreach (['Overdue' => '2028-03-05', 'Soon' => '2028-03-20', 'Later' => '2028-04-20'] as $title => $due) {
            $this->postJson('/api/v1/bills', ['title' => $title, 'amount' => 100, 'category' => 'bills', 'next_due_on' => $due])
                ->assertCreated();
        }

        $this->getJson('/api/v1/dashboard')
            ->assertOk()
            ->assertJsonCount(2, 'upcoming_bills')
            ->assertJsonPath('upcoming_bills.0.title', 'Overdue')
            ->assertJsonPath('upcoming_bills.1.title', 'Soon');
    }

    public function test_paydays_log_income_and_move_to_the_next_payday(): void
    {
        [, $alex] = $this->pair();
        Sanctum::actingAs($alex);
        $this->travelTo(now()->setDate(2026, 10, 16));

        $res = $this->postJson('/api/v1/paydays', ['amount' => 22500, 'frequency' => 'semimonthly', 'days' => [30, 15]])
            ->assertCreated()
            ->assertJsonPath('title', 'Salary')
            ->assertJsonPath('next_on', '2026-10-30')
            ->assertJsonPath('days', [15, 30])
            ->assertJsonPath('user.name', 'Alex')
            ->assertJsonMissingPath('day_a');
        $id = $res->json('id');

        // Take-home pay varies, so the logged amount can differ from the plan.
        $this->travelTo(now()->setDate(2026, 10, 30));
        $txn = $this->postJson("/api/v1/paydays/{$id}/receive", ['amount' => 23100.5])
            ->assertCreated()
            ->assertJsonPath('payday.next_on', '2026-11-15')
            ->assertJsonPath('transaction.type', 'income')
            ->assertJsonPath('transaction.category', 'income')
            ->assertJsonPath('transaction.amount', 23100.5)
            ->assertJsonPath('transaction.title', 'Salary')
            ->assertJsonPath('transaction.payment_method', 'bank')
            ->assertJsonPath('transaction.occurred_on', '2026-10-30')
            ->json('transaction.id');
        $this->postJson("/api/v1/paydays/{$id}/receive")
            ->assertJsonPath('payday.next_on', '2026-11-30')
            ->assertJsonPath('transaction.amount', 22500);
        $this->postJson("/api/v1/paydays/{$id}/receive")->assertJsonPath('payday.next_on', '2026-12-15');

        // Undo puts the date back and removes the income; a stranger's transaction is refused.
        $this->postJson("/api/v1/paydays/{$id}/unreceive", ['transaction_id' => $txn + 999, 'next_on' => '2026-11-30'])
            ->assertUnprocessable();
        $this->postJson("/api/v1/paydays/{$id}/unreceive", ['transaction_id' => $txn, 'next_on' => '2026-10-30'])
            ->assertOk()
            ->assertJsonPath('next_on', '2026-10-30');
        $this->getJson('/api/v1/transactions')->assertJsonCount(2, 'data');

        $this->postJson('/api/v1/paydays', ['amount' => 1, 'frequency' => 'semimonthly', 'days' => [15, 15]])
            ->assertUnprocessable()->assertJsonValidationErrors('days');
        $this->postJson('/api/v1/paydays', ['amount' => 1, 'frequency' => 'weekly'])
            ->assertUnprocessable()->assertJsonValidationErrors('next_on');
    }

    public function test_payday_schedules_handle_short_months(): void
    {
        [, $alex] = $this->pair();
        Sanctum::actingAs($alex);
        $this->travelTo(now()->setDate(2027, 2, 16));

        $twice = $this->postJson('/api/v1/paydays', ['amount' => 100, 'frequency' => 'semimonthly', 'days' => [15, 30]])
            ->assertJsonPath('next_on', '2027-02-28')->json('id');
        $this->postJson("/api/v1/paydays/{$twice}/receive")->assertJsonPath('payday.next_on', '2027-03-15');

        $monthly = $this->postJson('/api/v1/paydays', ['amount' => 100, 'frequency' => 'monthly', 'days' => [31]])
            ->assertJsonPath('next_on', '2027-02-28')->json('id');
        $this->postJson("/api/v1/paydays/{$monthly}/receive")->assertJsonPath('payday.next_on', '2027-03-31');
        $this->postJson("/api/v1/paydays/{$monthly}/receive")->assertJsonPath('payday.next_on', '2027-04-30');

        $biweekly = $this->postJson('/api/v1/paydays', ['amount' => 100, 'frequency' => 'biweekly', 'next_on' => '2027-02-19'])
            ->assertJsonPath('days', [])->json('id');
        $this->postJson("/api/v1/paydays/{$biweekly}/receive")->assertJsonPath('payday.next_on', '2027-03-05');

        // Switching to weekly drops the days of the month.
        $this->patchJson("/api/v1/paydays/{$twice}", ['frequency' => 'weekly', 'next_on' => '2027-02-20'])
            ->assertOk()->assertJsonPath('days', [])->assertJsonPath('next_on', '2027-02-20');
    }

    public function test_only_the_owner_can_change_or_log_a_payday(): void
    {
        [, $alex, $sam] = $this->pair();
        [, $other] = $this->pair();
        Sanctum::actingAs($alex);
        $this->travelTo(now()->setDate(2026, 10, 10));
        $id = $this->postJson('/api/v1/paydays', ['amount' => 22500, 'frequency' => 'monthly', 'days' => [25]])->json('id');

        Sanctum::actingAs($sam);
        $this->getJson('/api/v1/paydays')->assertOk()->assertJsonCount(1)->assertJsonPath('0.user.name', 'Alex');
        $this->getJson('/api/v1/dashboard')->assertJsonCount(1, 'paydays')->assertJsonPath('paydays.0.next_on', '2026-10-25');
        $this->patchJson("/api/v1/paydays/{$id}", ['amount' => 1])
            ->assertForbidden()->assertJsonPath('message', "Only Alex can change Alex's payday.");
        $this->postJson("/api/v1/paydays/{$id}/receive")->assertForbidden();
        $this->deleteJson("/api/v1/paydays/{$id}")->assertForbidden();

        Sanctum::actingAs($other);
        $this->getJson('/api/v1/paydays')->assertJsonCount(0);
        $this->postJson("/api/v1/paydays/{$id}/receive")->assertNotFound();

        Sanctum::actingAs($alex);
        $this->patchJson("/api/v1/paydays/{$id}", ['title' => 'Pay', 'amount' => 24000])
            ->assertOk()->assertJsonPath('amount', 24000)->assertJsonPath('next_on', '2026-10-25');
        $this->deleteJson("/api/v1/paydays/{$id}")->assertNoContent();
    }

    public function test_wallets_keep_a_running_balance(): void
    {
        [, $alex, $sam] = $this->pair();
        Sanctum::actingAs($alex);

        $gcash = $this->postJson('/api/v1/wallets', ['name' => 'GCash', 'kind' => 'ewallet', 'provider' => 'gcash', 'balance' => 5000])
            ->assertCreated()
            ->assertJsonPath('balance', 5000)
            ->assertJsonPath('is_shared', false)
            ->assertJsonPath('user.name', 'Alex')
            ->assertJsonMissingPath('opening_balance')
            ->json('id');
        $card = $this->postJson('/api/v1/wallets', ['name' => 'BPI Credit', 'kind' => 'credit', 'provider' => 'bpi', 'last4' => '4821'])
            ->assertJsonPath('last4', '4821')->json('id');

        $txn = fn (array $extra) => $this->postJson('/api/v1/transactions', $extra + [
            'type' => 'expense', 'amount' => 100, 'category' => 'food', 'title' => 'T', 'occurred_on' => '2028-03-05',
        ]);
        $txn(['amount' => 1200, 'wallet_id' => $gcash])->assertCreated()->assertJsonPath('payment_method', 'gcash');
        $txn(['type' => 'income', 'category' => 'income', 'amount' => 3000, 'wallet_id' => $gcash])->assertCreated();
        $txn(['amount' => 3200, 'wallet_id' => $card])->assertJsonPath('payment_method', 'card');
        $txn(['amount' => 50])->assertCreated();

        $this->getJson('/api/v1/wallets')
            ->assertJsonCount(2)
            ->assertJsonPath('0.balance', 6800)
            // A credit card goes below zero: what's owed.
            ->assertJsonPath('1.balance', -3200);

        // Correcting a balance after checking the bank app.
        $this->postJson("/api/v1/wallets/{$gcash}/balance", ['balance' => 6500])->assertOk()->assertJsonPath('balance', 6500);
        $txn(['amount' => 500, 'wallet_id' => $gcash]);
        $this->getJson('/api/v1/dashboard')->assertJsonPath('wallets.0.balance', 6000);

        // A shared wallet comes first and is open to both.
        $ours = $this->postJson('/api/v1/wallets', ['name' => 'Our Maya', 'kind' => 'ewallet', 'provider' => 'maya', 'is_shared' => true, 'balance' => 2000])
            ->assertJsonPath('is_shared', true)->assertJsonPath('user', null)->json('id');
        $this->getJson('/api/v1/wallets')->assertJsonPath('0.name', 'Our Maya');

        // Sam sees Alex's wallets by name, but not their balances.
        Sanctum::actingAs($sam);
        $this->getJson('/api/v1/wallets')
            ->assertJsonCount(3)
            ->assertJsonPath('0.balance', 2000)
            ->assertJsonPath('1.name', 'GCash')
            ->assertJsonPath('1.balance', null);
        $txn(['amount' => 100, 'wallet_id' => $gcash])->assertUnprocessable()->assertJsonValidationErrors('wallet_id');
        $txn(['amount' => 400, 'wallet_id' => $ours])->assertCreated();
        // Logging for Alex may use Alex's wallet.
        $txn(['amount' => 100, 'wallet_id' => $gcash, 'user_id' => $alex->id])->assertCreated();
        $this->patchJson("/api/v1/wallets/{$gcash}", ['name' => 'Mine now'])
            ->assertForbidden()->assertJsonPath('message', "Only Alex can change Alex's wallet.");
        $this->postJson("/api/v1/wallets/{$ours}/balance", ['balance' => 1500])->assertOk();

        Sanctum::actingAs($alex);
        $this->patchJson("/api/v1/wallets/{$gcash}", ['show_balance_to_partner' => true, 'name' => 'GCash'])->assertOk();
        Sanctum::actingAs($sam);
        $this->getJson('/api/v1/wallets')->assertJsonPath('1.balance', 5900)->assertJsonPath('0.balance', 1500);
    }

    public function test_a_used_wallet_is_archived_not_deleted(): void
    {
        [, $alex] = $this->pair();
        [, $other] = $this->pair();
        Sanctum::actingAs($alex);
        $unused = $this->postJson('/api/v1/wallets', ['name' => 'Cash', 'kind' => 'cash', 'provider' => 'cash'])->json('id');
        $used = $this->postJson('/api/v1/wallets', ['name' => 'BDO', 'kind' => 'debit', 'provider' => 'bdo'])->json('id');
        $this->postJson('/api/v1/transactions', [
            'type' => 'expense', 'amount' => 100, 'category' => 'food', 'title' => 'Lunch', 'occurred_on' => '2028-03-05', 'wallet_id' => $used,
        ])->assertCreated();
        $this->postJson('/api/v1/wallets', ['name' => 'X', 'kind' => 'debit', 'provider' => 'nope'])->assertUnprocessable();

        $this->deleteJson("/api/v1/wallets/{$unused}")->assertNoContent();
        $this->deleteJson("/api/v1/wallets/{$used}")->assertNoContent();
        $this->getJson('/api/v1/wallets')->assertJsonCount(0);
        // The transaction keeps its wallet; archived wallets can't take new ones.
        $this->getJson('/api/v1/transactions')->assertJsonPath('data.0.wallet_id', $used);
        $this->postJson('/api/v1/transactions', [
            'type' => 'expense', 'amount' => 1, 'category' => 'food', 'title' => 'X', 'occurred_on' => '2028-03-05', 'wallet_id' => $used,
        ])->assertUnprocessable();

        Sanctum::actingAs($other);
        $this->getJson('/api/v1/wallets')->assertJsonCount(0);
    }

    public function test_goal_contributions_update_progress(): void
    {
        [, $alex, $sam] = $this->pair();
        Sanctum::actingAs($alex);

        $id = $this->postJson('/api/v1/goals', ['name' => 'Japan Trip', 'target_amount' => 80000])->json('id');
        $this->postJson("/api/v1/goals/{$id}/contributions", ['amount' => 7000])->assertCreated();

        Sanctum::actingAs($sam);
        $this->postJson("/api/v1/goals/{$id}/contributions", ['amount' => 5000])
            ->assertJsonPath('saved', 12000)
            ->assertJsonPath('percent', 15)
            ->assertJsonCount(2, 'contributor_ids');
    }
    public function test_balance_shares_split_expenses_and_settling_up_evens_it(): void
    {
        [$couple, $alex, $sam] = $this->pair();
        $today = now()->toDateString();
        $couple->transactions()->createMany([
            ['user_id' => $alex->id, 'type' => 'expense', 'amount' => 3000, 'category' => 'food', 'title' => 'Groceries', 'is_split' => true, 'occurred_on' => $today],
            ['user_id' => $sam->id, 'type' => 'expense', 'amount' => 1000, 'category' => 'bills', 'title' => 'Internet', 'is_split' => true, 'occurred_on' => '2020-01-05'],
            ['user_id' => $sam->id, 'type' => 'expense', 'amount' => 5000, 'category' => 'shopping', 'title' => 'Shoes', 'is_split' => false, 'occurred_on' => $today],
            ['user_id' => $sam->id, 'type' => 'income', 'amount' => 9000, 'category' => 'income', 'title' => 'Salary', 'is_split' => true, 'occurred_on' => $today],
        ]);

        Sanctum::actingAs($alex);
        $this->getJson('/api/v1/balance')->assertOk()
            ->assertJsonPath('owes.from.name', 'Sam')
            ->assertJsonPath('owes.to.name', 'Alex')
            ->assertJsonPath('owes.amount', 1000)
            ->assertJsonPath('members.0.split_paid', 3000)
            ->assertJsonPath('members.1.paid_this_month', 5000);

        Sanctum::actingAs($sam);
        $id = $this->postJson('/api/v1/settlements', ['amount' => 400, 'from_user_id' => $sam->id])
            ->assertCreated()
            ->assertJsonPath('to.name', 'Alex')
            ->assertJsonPath('settled_on', $today)
            ->json('id');
        $this->getJson('/api/v1/balance')->assertJsonPath('owes.amount', 600);

        $this->postJson('/api/v1/settlements', ['amount' => 600, 'from_user_id' => $sam->id])->assertCreated();
        $this->getJson('/api/v1/balance')->assertJsonPath('owes', null)->assertJsonCount(2, 'settlements');

        Sanctum::actingAs($alex);
        $this->getJson('/api/v1/feed')->assertJsonFragment(['type' => 'settle', 'title' => 'Sam settled up with you', 'amount' => 600]);

        $this->deleteJson("/api/v1/settlements/{$id}")->assertNoContent();
        $this->getJson('/api/v1/balance')->assertJsonPath('owes.amount', 400);
    }

    public function test_settlements_stay_inside_the_couple(): void
    {
        [, $alex] = $this->pair();
        [, $other] = $this->pair();

        Sanctum::actingAs($alex);
        $this->postJson('/api/v1/settlements', ['amount' => 100, 'from_user_id' => $other->id])->assertUnprocessable();
        $id = $this->postJson('/api/v1/settlements', ['amount' => 100, 'from_user_id' => $alex->id])->json('id');

        Sanctum::actingAs($other);
        $this->deleteJson("/api/v1/settlements/{$id}")->assertNotFound();
    }

    public function test_no_balance_until_the_partner_joins(): void
    {
        $alex = User::factory()->for(Couple::create())->create();
        Sanctum::actingAs($alex);

        $this->getJson('/api/v1/balance')->assertOk()->assertJsonPath('owes', null)->assertJsonCount(0, 'members');
        $this->postJson('/api/v1/settlements', ['amount' => 100, 'from_user_id' => $alex->id])->assertUnprocessable();
    }

    public function test_an_expense_can_be_logged_as_paid_by_the_partner(): void
    {
        [, $alex, $sam] = $this->pair();
        [, $other] = $this->pair();
        $txn = ['type' => 'expense', 'amount' => 800, 'category' => 'food', 'title' => 'Dinner', 'is_split' => true, 'occurred_on' => '2025-05-01'];

        Sanctum::actingAs($alex);
        $id = $this->postJson('/api/v1/transactions', $txn + ['user_id' => $sam->id])
            ->assertCreated()->assertJsonPath('user.name', 'Sam')->json('id');
        $this->getJson('/api/v1/balance')->assertJsonPath('owes.from.name', 'Alex')->assertJsonPath('owes.amount', 400);

        $this->patchJson("/api/v1/transactions/{$id}", ['user_id' => $alex->id])->assertJsonPath('user.name', 'Alex');
        $this->postJson('/api/v1/transactions', $txn + ['user_id' => $other->id])->assertUnprocessable();
        $this->postJson('/api/v1/transactions', $txn)->assertCreated()->assertJsonPath('user.name', 'Alex');
    }
    public function test_a_contribution_is_a_transfer_that_is_saved_not_spent(): void
    {
        [$couple, $alex, $sam] = $this->pair();
        $goal = $couple->goals()->create(['name' => 'Japan Trip', 'target_amount' => 80000]);
        $couple->transactions()->create(['user_id' => $alex->id, 'type' => 'expense', 'amount' => 500, 'category' => 'food', 'title' => 'Lunch', 'occurred_on' => now()->toDateString()]);

        Sanctum::actingAs($alex);
        $transferId = $this->postJson("/api/v1/goals/{$goal->id}/contributions", ['amount' => 5000])
            ->assertCreated()
            ->assertJsonPath('saved', 5000)
            ->json('transaction_id');

        $this->getJson('/api/v1/transactions')
            ->assertJsonPath('data.0.id', $transferId)
            ->assertJsonPath('data.0.type', 'transfer')
            ->assertJsonPath('data.0.goal_id', $goal->id)
            ->assertJsonPath('data.0.title', 'Transfer to Japan Trip');
        $this->getJson('/api/v1/dashboard')
            ->assertJsonPath('budget.spent', 500)
            ->assertJsonPath('spending', ['food' => 500])
            ->assertJsonPath('saved_this_month', 5000);
        $this->getJson('/api/v1/balance')->assertJsonPath('members.0.paid_this_month', 500);

        Sanctum::actingAs($sam);
        $this->getJson('/api/v1/feed')->assertJsonCount(2)->assertJsonFragment(['type' => 'goal'])->assertJsonMissing(['subtitle' => 'Transfer to Japan Trip']);

        $this->patchJson("/api/v1/transactions/{$transferId}", ['amount' => 1])->assertUnprocessable();
        $this->deleteJson("/api/v1/transactions/{$transferId}")->assertNoContent();
        $this->getJson('/api/v1/goals')->assertJsonPath('0.saved', 0);
        $this->getJson('/api/v1/dashboard')->assertJsonPath('saved_this_month', 0);
    }

    public function test_transfers_only_come_from_goals_and_go_with_them(): void
    {
        [$couple, $alex] = $this->pair();
        $goal = $couple->goals()->create(['name' => 'Emergency Fund', 'target_amount' => 50000]);

        Sanctum::actingAs($alex);
        $this->postJson('/api/v1/transactions', [
            'type' => 'transfer', 'amount' => 100, 'category' => 'food', 'title' => 'Sneaky', 'occurred_on' => '2025-05-01',
        ])->assertUnprocessable();

        $this->postJson("/api/v1/goals/{$goal->id}/contributions", ['amount' => 1000])->assertCreated();
        $this->getJson('/api/v1/transactions?type=transfer')->assertJsonCount(1, 'data');

        $this->deleteJson("/api/v1/goals/{$goal->id}")->assertNoContent();
        $this->getJson('/api/v1/transactions')->assertJsonCount(0, 'data');
    }
    public function test_paying_a_bill_can_be_undone_without_losing_its_day(): void
    {
        [, $alex] = $this->pair();
        [, $other] = $this->pair();
        Sanctum::actingAs($alex);
        $id = $this->postJson('/api/v1/bills', [
            'title' => 'Rent', 'amount' => 15000, 'category' => 'bills', 'next_due_on' => '2028-01-31',
        ])->json('id');

        $paid = $this->postJson("/api/v1/bills/{$id}/pay")->assertCreated()->assertJsonPath('bill.next_due_on', '2028-02-29');
        $txnId = $paid->json('transaction.id');

        $lunch = $this->postJson('/api/v1/transactions', [
            'type' => 'expense', 'amount' => 200, 'category' => 'food', 'title' => 'Lunch', 'occurred_on' => '2028-01-31',
        ])->json('id');
        $this->postJson("/api/v1/bills/{$id}/unpay", ['transaction_id' => $lunch, 'next_due_on' => '2028-01-31'])->assertUnprocessable();

        Sanctum::actingAs($other);
        $this->postJson("/api/v1/bills/{$id}/unpay", ['transaction_id' => $txnId, 'next_due_on' => '2028-01-31'])->assertNotFound();

        Sanctum::actingAs($alex);
        $this->postJson("/api/v1/bills/{$id}/unpay", ['transaction_id' => $txnId, 'next_due_on' => '2028-01-31'])
            ->assertOk()
            ->assertJsonPath('next_due_on', '2028-01-31');
        $this->getJson('/api/v1/transactions')->assertJsonCount(1, 'data')->assertJsonPath('data.0.title', 'Lunch');

        // Still anchored to the 31st: Jan 31 → Feb 29 → Mar 31.
        $this->postJson("/api/v1/bills/{$id}/pay")->assertJsonPath('bill.next_due_on', '2028-02-29');
        $this->postJson("/api/v1/bills/{$id}/pay")->assertJsonPath('bill.next_due_on', '2028-03-31');
    }
    public function test_guessing_keys_is_limited_without_blocking_onboarding(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/recover', ['recovery_key' => "WRNG-KEYS-0000-000{$i}"])->assertUnprocessable();
        }
        $this->postJson('/api/v1/auth/recover', ['recovery_key' => 'WRNG-KEYS-0000-0009'])->assertStatus(429);
        $this->postJson('/api/v1/auth/relink/redeem', ['code' => 'ABCDEFGH'])->assertStatus(429);

        // Onboarding has its own counter.
        $this->postJson('/api/v1/auth/start', ['name' => 'Alex'])->assertCreated();
    }
    public function test_cancelling_a_goal_releases_its_savings_and_can_be_undone(): void
    {
        [$couple, $alex, $sam] = $this->pair();
        [, $other] = $this->pair();
        $goal = $couple->goals()->create(['name' => 'Japan Trip', 'target_amount' => 80000]);
        $couple->transactions()->create(['user_id' => $alex->id, 'type' => 'expense', 'amount' => 900, 'category' => 'food', 'title' => 'Groceries', 'is_split' => true, 'occurred_on' => now()->toDateString()]);

        Sanctum::actingAs($alex);
        $this->postJson("/api/v1/goals/{$goal->id}/contributions", ['amount' => 5000])->assertCreated();
        $this->postJson("/api/v1/goals/{$goal->id}/contributions", ['amount' => 7000])->assertCreated();
        $before = $this->getJson('/api/v1/balance')->json('owes');

        Sanctum::actingAs($other);
        $this->postJson("/api/v1/goals/{$goal->id}/cancel")->assertNotFound();

        Sanctum::actingAs($sam);
        $this->postJson("/api/v1/goals/{$goal->id}/cancel")
            ->assertOk()
            ->assertJsonPath('cancelled', true)
            ->assertJsonPath('saved', 12000);
        $this->postJson("/api/v1/goals/{$goal->id}/cancel")->assertUnprocessable();
        $this->postJson("/api/v1/goals/{$goal->id}/contributions", ['amount' => 100])->assertUnprocessable();

        $release = collect($this->getJson('/api/v1/transactions?type=release')->assertJsonCount(1, 'data')->json('data'))->first();
        $this->assertSame('Released from Japan Trip', $release['title']);
        $this->assertEquals(12000, $release['amount']);
        $this->getJson('/api/v1/dashboard')
            ->assertJsonPath('saved_this_month', 0)
            ->assertJsonPath('budget.spent', 900);
        $this->assertEquals($before, $this->getJson('/api/v1/balance')->json('owes'));
        $this->patchJson("/api/v1/transactions/{$release['id']}", ['amount' => 1])->assertUnprocessable();
        $this->deleteJson("/api/v1/transactions/{$release['id']}")->assertUnprocessable();

        Sanctum::actingAs($alex);
        $this->getJson('/api/v1/feed')->assertJsonFragment(['title' => 'Sam cancelled Japan Trip']);
        $this->getJson('/api/v1/goals')->assertJsonPath('0.cancelled', true);

        $this->postJson("/api/v1/goals/{$goal->id}/restore")->assertOk()->assertJsonPath('cancelled', false)->assertJsonPath('saved', 12000);
        $this->getJson('/api/v1/transactions?type=release')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/dashboard')->assertJsonPath('saved_this_month', 12000);
        $this->postJson("/api/v1/goals/{$goal->id}/contributions", ['amount' => 100])->assertCreated();
    }
    public function test_transactions_by_date_range_and_bigger_pages(): void
    {
        [$couple, $alex] = $this->pair();
        $row = fn (string $day, string $title) => ['user_id' => $alex->id, 'type' => 'expense', 'amount' => 10, 'category' => 'food', 'title' => $title, 'occurred_on' => $day];
        $couple->transactions()->createMany([
            $row('2028-01-31', 'Before'),
            $row('2028-02-01', 'First day'),
            $row('2028-02-20', 'Middle'),
            $row('2028-03-10', 'Last day'),
            $row('2028-03-11', 'After'),
        ]);
        for ($i = 0; $i < 31; $i++) {
            $couple->transactions()->create($row('2028-06-15', "Coffee {$i}"));
        }

        Sanctum::actingAs($alex);
        $titles = collect($this->getJson('/api/v1/transactions?from=2028-02-01&to=2028-03-10')->assertOk()->json('data'))->pluck('title')->all();
        $this->assertSame(['Last day', 'Middle', 'First day'], $titles);

        $this->getJson('/api/v1/transactions?month=2028-06')->assertJsonCount(30, 'data');
        $this->getJson('/api/v1/transactions?month=2028-06&per_page=500')->assertJsonCount(31, 'data');

        $this->getJson('/api/v1/transactions?from=2028-03-10&to=2028-02-01')->assertUnprocessable();
        $this->getJson('/api/v1/transactions?from=2027-01-01&to=2028-06-30')->assertUnprocessable();
        $this->getJson('/api/v1/transactions?per_page=501')->assertUnprocessable();
    }
    public function test_profile_photos_are_private_to_the_couple(): void
    {
        Storage::fake('local');
        [, $alex, $sam] = $this->pair();
        [, $other] = $this->pair();

        Sanctum::actingAs($alex);
        $this->postJson('/api/v1/me/avatar', ['photo' => UploadedFile::fake()->create('notes.pdf', 10, 'application/pdf')])->assertUnprocessable();
        $first = $this->postJson('/api/v1/me/avatar', ['photo' => UploadedFile::fake()->image('me.png', 900, 600)])
            ->assertOk()
            ->assertJsonMissingPath('user.avatar_path')
            ->json('user.avatar_version');
        $this->assertNotNull($first);
        $path = $alex->fresh()->avatar_path;
        Storage::disk('local')->assertExists($path);
        [$w, $h, $type] = getimagesizefromstring(Storage::disk('local')->get($path));
        $this->assertSame([512, 512, IMAGETYPE_JPEG], [$w, $h, $type]);

        Sanctum::actingAs($sam);
        $this->get("/api/v1/members/{$alex->id}/avatar")->assertOk()->assertHeader('Content-Type', 'image/jpeg');
        $this->getJson('/api/v1/couple')->assertJsonPath('couple.members.0.avatar_version', $first);
        $this->get("/api/v1/members/{$sam->id}/avatar")->assertNotFound();

        Sanctum::actingAs($other);
        $this->get("/api/v1/members/{$alex->id}/avatar")->assertNotFound();

        Sanctum::actingAs($alex);
        $this->travel(2)->seconds();
        $second = $this->postJson('/api/v1/me/avatar', ['photo' => UploadedFile::fake()->image('new.jpg', 400, 800)])->json('user.avatar_version');
        $this->assertNotSame($first, $second);
        Storage::disk('local')->assertMissing($path);

        $this->deleteJson('/api/v1/me/avatar')->assertOk()->assertJsonPath('user.avatar_version', null);
        $this->get("/api/v1/members/{$alex->id}/avatar")->assertNotFound();
        $this->assertCount(0, Storage::disk('local')->allFiles('avatars'));
    }
}
