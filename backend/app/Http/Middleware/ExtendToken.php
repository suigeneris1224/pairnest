<?php

namespace App\Http\Middleware;

use App\Http\Controllers\AuthController;
use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;

/**
 * Keeps a phone signed in while it's used: a token lasts TOKEN_DAYS from its
 * last use. Written at most every couple of weeks, not on every request.
 */
class ExtendToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->user()?->currentAccessToken();
        // Only stored tokens; tests act with in-memory ones.
        if ($token instanceof PersonalAccessToken && $token->exists === true) {
            $renewAt = now()->addDays(AuthController::TOKEN_DAYS - 14);
            if ($token->expires_at === null || $token->expires_at->lt($renewAt)) {
                $token->forceFill(['expires_at' => now()->addDays(AuthController::TOKEN_DAYS)])->save();
            }
        }

        return $next($request);
    }
}
