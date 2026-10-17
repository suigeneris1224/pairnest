<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call(ConversationPromptSeeder::class);

        if (app()->environment('local')) {
            $this->call(DemoCoupleSeeder::class);
        }
    }
}
