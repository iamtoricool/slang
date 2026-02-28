<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Language;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class TranslationManagementController extends Controller
{
    // Helper: Deep merge arrays
    private function deepMerge($target, $source)
    {
        if (!is_array($target) || !is_array($source)) {
            return $source;
        }

        $result = $target;
        foreach ($source as $key => $value) {
            if (is_array($value) && isset($result[$key]) && is_array($result[$key])) {
                $result[$key] = $this->deepMerge($result[$key], $value);
            } else {
                $result[$key] = $value;
            }
        }
        return $result;
    }

    // GET /api/languages/{code}/translations
    public function show(string $code)
    {
        $language = Language::where('code', $code)->first();

        if (!$language) {
            return response()->json(['error' => 'Language not found'], 404);
        }

        return response()->json([
            'translations' => $language->translations,
            'hash' => $language->hash,
            'updatedAt' => $language->updated_at->toIso8601String(),
        ]);
    }

    // PUT /api/languages/{code}/translations - Full replace
    public function replace(Request $request, string $code)
    {
        $language = Language::where('code', $code)->first();

        if (!$language) {
            return response()->json(['error' => 'Language not found'], 404);
        }

        $validator = Validator::make($request->all(), [
            'translations' => 'required|array',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 400);
        }

        $language->update([
            'translations' => $request->translations,
        ]);

        return response()->json([
            'code' => $language->code,
            'hash' => $language->hash,
            'updatedAt' => $language->updated_at->toIso8601String(),
            'translations' => $language->translations,
        ]);
    }

    // PATCH /api/languages/{code}/translations - Merge
    public function merge(Request $request, string $code)
    {
        $language = Language::where('code', $code)->first();

        if (!$language) {
            return response()->json(['error' => 'Language not found'], 404);
        }

        $validator = Validator::make($request->all(), [
            'translations' => 'required|array',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 400);
        }

        $merged = $this->deepMerge($language->translations, $request->translations);

        $language->update([
            'translations' => $merged,
        ]);

        return response()->json([
            'code' => $language->code,
            'hash' => $language->hash,
            'updatedAt' => $language->updated_at->toIso8601String(),
            'translations' => $language->translations,
        ]);
    }

    // POST /api/languages/{code}/translations - Add keys
    public function add(Request $request, string $code)
    {
        $language = Language::where('code', $code)->first();

        if (!$language) {
            return response()->json(['error' => 'Language not found'], 404);
        }

        if (!is_array($request->all())) {
            return response()->json(['error' => 'Request body must be a JSON object'], 400);
        }

        $merged = $this->deepMerge($language->translations, $request->all());

        $language->update([
            'translations' => $merged,
        ]);

        return response()->json([
            'code' => $language->code,
            'hash' => $language->hash,
            'updatedAt' => $language->updated_at->toIso8601String(),
            'translations' => $language->translations,
        ]);
    }
}
