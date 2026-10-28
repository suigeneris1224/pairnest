<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PlanController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $plans = $request->user()->couple->plans()
            ->with(['goal' => fn ($q) => $q->withSum('contributions as saved', 'amount')])
            ->orderByRaw('scheduled_at IS NULL')
            ->orderBy('scheduled_at')
            ->limit(200)
            ->get();

        return response()->json($plans);
    }

    public function store(Request $request): JsonResponse
    {
        $plan = $request->user()->couple->plans()->create($this->validated($request));

        return response()->json($plan->load('goal'), 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $plan = $request->user()->couple->plans()->findOrFail($id);
        $plan->update($this->validated($request, partial: true));

        return response()->json($plan->load('goal'));
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $request->user()->couple->plans()->findOrFail($id)->delete();

        return response()->json(null, 204);
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $req = $partial ? 'sometimes' : 'required';
        $coupleId = $request->user()->couple_id;

        return $request->validate([
            'kind' => [$req, Rule::in(['date', 'life'])],
            'title' => [$req, 'string', 'max:120'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'scheduled_at' => ['nullable', 'date', 'after_or_equal:2000-01-01', 'before:2100-01-01'],
            'goal_id' => ['nullable', Rule::exists('goals', 'id')->where('couple_id', $coupleId)],
        ]);
    }
}
