<?php

namespace Database\Seeders;

use App\Models\ConversationPrompt;
use Illuminate\Database\Seeder;

class ConversationPromptSeeder extends Seeder
{
    private const PROMPTS = [
        'dreams' => [
            "What's one thing you'd love to save for together this year?",
            'Where do you see us living in five years?',
            'What would a perfect, budget-friendly weekend look like for you?',
            'If money were no object for a day, how would we spend it together?',
            'What experience do you want us to share before we turn older?',
        ],
        'worries' => [
            'Is there anything about our budget that worries you?',
            'What money habit of yours would you like to change?',
            'How do you feel when we disagree about spending?',
            'Is there a bill or expense you have been avoiding thinking about?',
        ],
        'reflection' => [
            'What made you happiest with our spending this week?',
            'What is one money win we had this month that we should celebrate?',
            'What did your family teach you about money growing up?',
            'Which purchase this month felt most worth it, and why?',
            'How did our last shared goal make you feel when we reached it?',
        ],
        'teamwork' => [
            'How can I support you better with our finances?',
            'Should we try a no-spend weekend soon? What would we do instead?',
            'How would you like us to split chores around money, like paying bills?',
            'What is one small thing we could cut back on together?',
            'How often would you like to check in on our budget together?',
        ],
        'gratitude' => [
            'What is something I did recently that made you feel cared for?',
            'What free activity with me do you enjoy the most?',
            'What are you most grateful for in our life right now?',
            'Which memory together do you treasure that cost almost nothing?',
        ],
    ];

    public function run(): void
    {
        foreach (self::PROMPTS as $topic => $questions) {
            foreach ($questions as $question) {
                ConversationPrompt::firstOrCreate(['question' => $question], ['topic' => $topic]);
            }
        }
    }
}
