<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Phones unused for AuthController::TOKEN_DAYS are signed out for good.
Schedule::command('sanctum:prune-expired --hours=24')->daily();
