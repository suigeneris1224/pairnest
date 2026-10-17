<?php

namespace App\Http\Controllers;

use App\Models\MoodCheckin;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class MoodController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $moods = $user->couple->moods()
            ->visibleTo($user)
            ->with('user:id,name')
            ->latest()
            ->limit(100)
            ->get();

        return response()->json($moods);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'mood' => ['required', Rule::in(MoodCheckin::MOODS)],
            'note' => ['nullable', 'string', 'max:500'],
            'is_private' => ['sometimes', 'boolean'],
        ]);

        $mood = $request->user()->couple->moods()->create($data + ['user_id' => $request->user()->id]);

        return response()->json($mood->load('user:id,name'), 201);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $request->user()->couple->moods()->where('user_id', $request->user()->id)->findOrFail($id)->delete();

        return response()->json(null, 204);
    }
}
