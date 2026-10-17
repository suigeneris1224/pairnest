<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\AvatarController;
use App\Http\Controllers\BillController;
use App\Http\Controllers\BudgetController;
use App\Http\Controllers\CoupleController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\FeedController;
use App\Http\Controllers\GoalController;
use App\Http\Controllers\MoodController;
use App\Http\Controllers\PlanController;
use App\Http\Controllers\SettlementController;
use App\Http\Controllers\TalkController;
use App\Http\Controllers\TransactionController;
use App\Http\Middleware\EnsureCouple;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::get('health', fn () => ['status' => 'ok']);

    Route::post('auth/start', [AuthController::class, 'start'])->middleware('throttle:auth-start');
    // Guessing keys or codes is rate-limited hard.
    Route::middleware('throttle:auth-guess')->group(function () {
        Route::post('auth/recover', [AuthController::class, 'recover']);
        Route::post('auth/relink/redeem', [AuthController::class, 'redeemRelink']);
    });

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::post('auth/recovery-key', [AuthController::class, 'recoveryKey']);
        Route::post('me/avatar', [AvatarController::class, 'store']);
        Route::delete('me/avatar', [AvatarController::class, 'destroy']);
        Route::get('members/{id}/avatar', [AvatarController::class, 'show'])->whereNumber('id');

        Route::get('couple', [CoupleController::class, 'show']);
        Route::post('couple', [CoupleController::class, 'store']);
        Route::post('couple/join', [CoupleController::class, 'join'])->middleware('throttle:10,1');

        Route::middleware(EnsureCouple::class)->group(function () {
            Route::patch('couple', [CoupleController::class, 'update']);
            Route::post('auth/relink', [AuthController::class, 'relink']);
            Route::get('dashboard', DashboardController::class);
            Route::get('feed', FeedController::class);

            Route::get('budgets/{month}', [BudgetController::class, 'show']);
            Route::put('budgets/{month}', [BudgetController::class, 'upsert']);

            Route::apiResource('transactions', TransactionController::class)->except('show');
            Route::apiResource('goals', GoalController::class)->except('show');
            Route::post('goals/{goal}/contributions', [GoalController::class, 'contribute']);
            Route::post('goals/{goal}/cancel', [GoalController::class, 'cancel']);
            Route::post('goals/{goal}/restore', [GoalController::class, 'restore']);
            Route::apiResource('moods', MoodController::class)->only(['index', 'store', 'destroy']);
            Route::apiResource('plans', PlanController::class)->except('show');
            Route::apiResource('bills', BillController::class)->except('show');
            Route::post('bills/{bill}/pay', [BillController::class, 'pay']);
            Route::post('bills/{bill}/unpay', [BillController::class, 'unpay']);
            Route::get('balance', [SettlementController::class, 'balance']);
            Route::apiResource('settlements', SettlementController::class)->only(['store', 'destroy']);

            Route::get('talks/current', [TalkController::class, 'current']);
            Route::post('talks/current/answer', [TalkController::class, 'answer']);
            Route::get('talks/history', [TalkController::class, 'history']);
        });
    });
});
