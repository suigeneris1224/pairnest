<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\AvatarController;
use App\Http\Controllers\BillController;
use App\Http\Controllers\PaydayController;
use App\Http\Controllers\WalletController;
use App\Http\Controllers\BudgetController;
use App\Http\Controllers\CoupleController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\FeedController;
use App\Http\Controllers\GoalController;
use App\Http\Controllers\MoodController;
use App\Http\Controllers\MoveController;
use App\Http\Controllers\PlanController;
use App\Http\Controllers\SettlementController;
use App\Http\Controllers\TalkController;
use App\Http\Controllers\TransactionController;
use App\Http\Middleware\EnsureCouple;
use App\Http\Middleware\ExtendToken;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::get('health', fn () => ['status' => 'ok']);

    Route::post('auth/start', [AuthController::class, 'start'])->middleware('throttle:auth-start');
    // Guessing keys or codes is rate-limited hard.
    Route::middleware('throttle:auth-guess')->group(function () {
        Route::post('auth/recover', [AuthController::class, 'recover']);
        Route::post('auth/relink/redeem', [AuthController::class, 'redeemRelink']);
    });

    Route::middleware(['auth:sanctum', ExtendToken::class, 'throttle:api'])->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::post('auth/recovery-key', [AuthController::class, 'recoveryKey']);
        Route::get('auth/devices', [AuthController::class, 'devices']);
        Route::delete('auth/devices/{id}', [AuthController::class, 'removeDevice'])->whereNumber('id');
        Route::post('me/avatar', [AvatarController::class, 'store'])->middleware('throttle:avatar');
        Route::delete('me/avatar', [AvatarController::class, 'destroy']);
        Route::get('members/{id}/avatar', [AvatarController::class, 'show'])->whereNumber('id');

        Route::get('couple', [CoupleController::class, 'show']);
        Route::post('couple', [CoupleController::class, 'store']);
        // Per account and per IP, since onboarding hands out new accounts.
        Route::post('couple/join', [CoupleController::class, 'join'])->middleware('throttle:couple-join');

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
            Route::apiResource('paydays', PaydayController::class)->except('show');
            Route::apiResource('wallets', WalletController::class)->except('show');
            Route::post('wallets/{wallet}/balance', [WalletController::class, 'balance']);
            Route::post('moves', [MoveController::class, 'store']);
            Route::post('paydays/{payday}/receive', [PaydayController::class, 'receive']);
            Route::post('paydays/{payday}/unreceive', [PaydayController::class, 'unreceive']);
            Route::get('balance', [SettlementController::class, 'balance']);
            Route::apiResource('settlements', SettlementController::class)->only(['store', 'update', 'destroy']);

            Route::get('talks/current', [TalkController::class, 'current']);
            Route::post('talks/current/answer', [TalkController::class, 'answer']);
            Route::get('talks/history', [TalkController::class, 'history']);
        });
    });
});
