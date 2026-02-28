<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Language;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class LanguageController extends Controller
{
    // GET /api/languages - List all (metadata only)
    public function index()
    {
        $languages = Language::all()->map(fn($lang) => $lang->metadata);
        return response()->json($languages);
    }

    // GET /api/languages/{code} - Get with translations
    public function show(string $code)
    {
        $language = Language::where('code', $code)->first();

        if (!$language) {
            return response()->json(['error' => 'Language not found'], 404);
        }

        return response()->json([
            'code' => $language->code,
            'name' => $language->name,
            'nativeName' => $language->native_name,
            'translations' => $language->translations,
            'hash' => $language->hash,
            'createdAt' => $language->created_at->toIso8601String(),
            'updatedAt' => $language->updated_at->toIso8601String(),
        ]);
    }

    // POST /api/languages - Create
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'code' => 'required|string|size:2|unique:languages,code',
            'name' => 'required|string',
            'nativeName' => 'nullable|string',
            'translations' => 'nullable|array',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 400);
        }

        $language = Language::create([
            'code' => strtolower($request->code),
            'name' => $request->name,
            'native_name' => $request->nativeName,
            'translations' => $request->translations ?? [],
        ]);

        return response()->json($language->metadata, 201);
    }

    // PUT /api/languages/{code} - Full replace
    public function update(Request $request, string $code)
    {
        $language = Language::where('code', $code)->first();

        if (!$language) {
            return response()->json(['error' => 'Language not found'], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'nullable|string',
            'nativeName' => 'nullable|string',
            'translations' => 'nullable|array',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 400);
        }

        $language->update([
            'name' => $request->name ?? $language->name,
            'native_name' => $request->nativeName ?? $language->native_name,
            'translations' => $request->translations ?? $language->translations,
        ]);

        return response()->json($language->metadata);
    }

    // PATCH /api/languages/{code} - Partial update metadata only
    public function patch(Request $request, string $code)
    {
        $language = Language::where('code', $code)->first();

        if (!$language) {
            return response()->json(['error' => 'Language not found'], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'nullable|string',
            'nativeName' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 400);
        }

        $language->update([
            'name' => $request->name ?? $language->name,
            'native_name' => $request->nativeName ?? $language->native_name,
        ]);

        return response()->json($language->metadata);
    }

    // DELETE /api/languages/{code}
    public function destroy(string $code)
    {
        $language = Language::where('code', $code)->first();

        if (!$language) {
            return response()->json(['error' => 'Language not found'], 404);
        }

        $language->delete();

        return response()->json(['message' => 'Language deleted successfully']);
    }
}
