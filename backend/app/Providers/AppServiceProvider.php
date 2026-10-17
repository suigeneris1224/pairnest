<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Separate counters per limit: plain throttle:N,1 shares one counter per
        // IP across routes, so a household onboarding twice would eat into the
        // recovery attempts.
        RateLimiter::for('auth-start', fn (Request $request) => Limit::perMinute(10)->by('start|'.$request->ip()));
        // Guessing recovery keys or re-link codes is limited hard.
        RateLimiter::for('auth-guess', fn (Request $request) => Limit::perMinute(5)->by('guess|'.$request->ip()));
    }
}
