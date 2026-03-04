<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\TranslationController;
use App\Http\Controllers\Api\LanguageController;
use App\Http\Controllers\Api\TranslationManagementController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Health check
Route::get('/', function () {
    return response()->json([
        'status' => 'ok',
        'service' => 'slang-cloud-server',
        'version' => '1.0.0',
        'languages' => \App\Models\Language::count(),
        'admin' => '/admin',
    ]);
});

// Translation endpoints (for slang_cloud client)
// Primary endpoints that match SlangCloudClient expectations
Route::match(['get', 'head'], '/translations/{locale}', [TranslationController::class, 'download']);

// Alternative endpoints (for explicit actions)
Route::get('/translations/{locale}/check', [TranslationController::class, 'check']);
Route::get('/translations/{locale}/download', [TranslationController::class, 'download']);

// Language management
Route::apiResource('languages', LanguageController::class)->parameters([
    'languages' => 'code'
]);

// Translation management
Route::prefix('languages/{code}')->group(function () {
    Route::get('/translations', [TranslationManagementController::class, 'show']);
    Route::put('/translations', [TranslationManagementController::class, 'replace']);
    Route::patch('/translations', [TranslationManagementController::class, 'merge']);
    Route::post('/translations', [TranslationManagementController::class, 'add']);
});
