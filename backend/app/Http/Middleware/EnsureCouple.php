<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureCouple
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user()?->couple_id === null) {
            return response()->json(['message' => 'Create or join a nest with your partner first.'], 409);
        }

        return $next($request);
    }
}
