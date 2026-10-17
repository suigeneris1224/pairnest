<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\StarterGoals;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Anonymous accounts. Onboarding creates one (a token on the phone plus a
 * recovery key shown once); a new phone gets back in with that key or a
 * one-time re-link code from the partner's phone. No email, no password.
 */
class AuthController extends Controller
{
    private const RELINK_MINUTES = 10;

    public function start(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:40'],
            'profile' => ['sometimes', 'array'],
            'profile.partner_name' => ['nullable', 'string', 'max:40'],
            'profile.stage' => ['nullable', Rule::in(User::STAGES)],
            'profile.financial_goals' => ['sometimes', 'array', 'max:8'],
            'profile.financial_goals.*' => [Rule::in(StarterGoals::FINANCIAL)],
            'profile.family_goals' => ['sometimes', 'array', 'max:5'],
            'profile.family_goals.*' => [Rule::in(StarterGoals::FAMILY)],
            'profile.money_style' => ['nullable', Rule::in(User::MONEY_STYLES)],
            'profile.monthly_budget' => ['nullable', 'numeric', 'min:0', 'max:9999999999'],
        ]);

        $user = User::create(['name' => trim($data['name']), 'profile' => $data['profile'] ?? null]);
        $key = $user->issueRecoveryKey();

        return response()->json($this->session($user) + ['recovery_key' => $key], 201);
    }

    public function recover(Request $request): JsonResponse
    {
        $data = $request->validate(['recovery_key' => ['required', 'string', 'max:40']]);
        $user = User::where('recovery_key_hash', User::hashRecoveryKey($data['recovery_key']))->first();
        if (! $user) {
            throw ValidationException::withMessages(['recovery_key' => "That recovery key doesn't match any nest."]);
        }

        // The lost phone loses access.
        $user->tokens()->delete();

        return response()->json($this->session($user));
    }

    /** Called on the partner's phone: a short code that signs their partner back in. */
    public function relink(Request $request): JsonResponse
    {
        $me = $request->user();
        $partner = $me->couple->members()->where('id', '!=', $me->id)->first();
        if (! $partner) {
            throw ValidationException::withMessages(['partner' => 'Your partner needs to join before you can re-link their phone.']);
        }

        $code = User::randomCode(8);
        $expires = now()->addMinutes(self::RELINK_MINUTES);
        Cache::put("relink:{$code}", $partner->id, $expires);

        return response()->json([
            'code' => $code,
            'expires_at' => $expires->toIso8601ZuluString(),
            'for' => $partner->name,
        ], 201);
    }

    public function redeemRelink(Request $request): JsonResponse
    {
        $data = $request->validate(['code' => ['required', 'string', 'max:20']]);
        $code = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $data['code']));
        $userId = Cache::pull("relink:{$code}");
        $user = $userId ? User::find($userId) : null;
        if (! $user) {
            throw ValidationException::withMessages(['code' => 'That code has expired or was already used. Ask your partner for a new one.']);
        }

        $user->tokens()->delete();

        return response()->json($this->session($user));
    }

    /** A fresh recovery key; the old one stops working. */
    public function recoveryKey(Request $request): JsonResponse
    {
        return response()->json(['recovery_key' => $request->user()->issueRecoveryKey()], 201);
    }

    /** "Remove this phone." */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'This phone was removed.']);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(['user' => $request->user()->load('couple.members')]);
    }

    private function session(User $user): array
    {
        return [
            'token' => $user->createToken('pairnest')->plainTextToken,
            'user' => $user->load('couple.members'),
        ];
    }
}
