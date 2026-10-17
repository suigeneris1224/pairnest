<?php

namespace App\Http\Controllers;

use App\Models\ConversationPrompt;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TalkController extends Controller
{
    public function current(Request $request): JsonResponse
    {
        $couple = $request->user()->couple;
        $prompt = ConversationPrompt::forWeek($couple);
        abort_unless($prompt, 404, 'No conversation prompts yet.');

        $answers = $couple->answers()
            ->where('conversation_prompt_id', $prompt->id)
            ->with('user:id,name')
            ->get();

        // Partner answers stay hidden until you share yours.
        $answeredByMe = $answers->contains('user_id', $request->user()->id);

        return response()->json([
            'prompt' => $prompt,
            'answered' => $answeredByMe,
            'answers' => $answeredByMe ? $answers : [],
        ]);
    }

    public function answer(Request $request): JsonResponse
    {
        $data = $request->validate(['answer' => ['required', 'string', 'max:1000']]);
        $couple = $request->user()->couple;
        $prompt = ConversationPrompt::forWeek($couple);
        abort_unless($prompt, 404, 'No conversation prompts yet.');

        $couple->answers()->updateOrCreate(
            ['conversation_prompt_id' => $prompt->id, 'user_id' => $request->user()->id],
            ['answer' => $data['answer']],
        );

        return $this->current($request);
    }

    public function history(Request $request): JsonResponse
    {
        $couple = $request->user()->couple;
        $current = ConversationPrompt::forWeek($couple);

        $past = $couple->answers()
            ->with('prompt', 'user:id,name')
            ->when($current, fn ($q) => $q->where('conversation_prompt_id', '!=', $current->id))
            ->latest()
            ->get()
            ->groupBy('conversation_prompt_id')
            ->map(fn ($answers) => [
                'prompt' => $answers->first()->prompt,
                'last_answered_at' => $answers->max('created_at'),
                'answers' => $answers->values(),
            ])
            ->values();

        return response()->json($past);
    }
}
