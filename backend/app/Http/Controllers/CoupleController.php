<?php

namespace App\Http\Controllers;

use App\Models\Couple;
use App\Models\Wallet;
use App\Services\StarterGoals;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class CoupleController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return response()->json(['couple' => $request->user()->couple?->load('members')]);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        $this->ensureSingle($user->couple_id);

        $data = $request->validate(['theme' => ['sometimes', Rule::in(Couple::THEMES)]]);
        $couple = DB::transaction(function () use ($data, $user) {
            $couple = Couple::create($data);
            $user->couple()->associate($couple)->save();
            StarterGoals::forNewNest($couple, $user);
            Wallet::ensureCash($couple, $user);

            return $couple;
        });

        return response()->json(['couple' => $couple->load('members')], 201);
    }

    public function join(Request $request): JsonResponse
    {
        $user = $request->user();
        $this->ensureSingle($user->couple_id);

        $data = $request->validate(['code' => ['required', 'string', 'size:6']]);
        // Locked so two people joining at once can't both become the second partner.
        $couple = DB::transaction(function () use ($data, $user) {
            $couple = Couple::where('invite_code', strtoupper($data['code']))->lockForUpdate()->first();
            if (! $couple) {
                throw ValidationException::withMessages(['code' => 'We couldn\'t find a nest with that code.']);
            }
            if ($couple->members()->count() >= Couple::MAX_MEMBERS) {
                throw ValidationException::withMessages(['code' => 'This nest already has two partners.']);
            }

            $user->couple()->associate($couple)->save();
            StarterGoals::addGoals($couple, $user);
            Wallet::ensureCash($couple, $user);

            return $couple;
        });

        return response()->json(['couple' => $couple->load('members')]);
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate(['theme' => ['required', Rule::in(Couple::THEMES)]]);
        $couple = $request->user()->couple;
        $couple->update($data);

        return response()->json(['couple' => $couple->load('members')]);
    }

    private function ensureSingle(?int $coupleId): void
    {
        if ($coupleId !== null) {
            throw ValidationException::withMessages(['couple' => 'You are already in a nest.']);
        }
    }
}
