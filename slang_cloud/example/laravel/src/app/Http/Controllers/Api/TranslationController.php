<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Language;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\File;

class TranslationController extends Controller
{
    // HEAD /api/translations/{locale}/check - Check version
    public function check(string $locale)
    {
        $language = Language::where('code', $locale)->first();

        if (!$language) {
            return response(null, 404)->header('Content-Type', 'application/json');
        }

        return response(null, 200)
            ->header('X-Translation-Hash', $language->hash)
            ->header('Content-Type', 'application/json');
    }

    // GET /api/translations/{locale}/download - Download as file
    public function download(string $locale)
    {
        $language = Language::where('code', $locale)->first();

        if (!$language) {
            return response()->json(['error' => 'Language not found'], 404);
        }

        $jsonContent = json_encode($language->translations, JSON_PRETTY_PRINT);

        return response($jsonContent, 200)
            ->header('Content-Type', 'application/json')
            ->header('Content-Disposition', "attachment; filename=\"{$locale}.json\"")
            ->header('X-Translation-Hash', $language->hash);
    }
}
