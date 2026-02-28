<?php

namespace Database\Seeders;

use App\Models\Language;
use Illuminate\Database\Seeder;

class LanguageSeeder extends Seeder
{
    public function run(): void
    {
        Language::create([
            'code' => 'en',
            'name' => 'English',
            'native_name' => 'English',
            'translations' => [
                'main' => [
                    'title' => 'Slang Cloud Demo (Server)',
                    'description' => 'This text is served from the Laravel backend!',
                    'button' => 'Check for Updates',
                ],
            ],
        ]);

        Language::create([
            'code' => 'de',
            'name' => 'German',
            'native_name' => 'Deutsch',
            'translations' => [
                'main' => [
                    'title' => 'Slang Cloud Demo (Server DE)',
                    'description' => 'Dieser Text kommt vom Laravel Backend!',
                    'button' => 'Nach Updates suchen',
                ],
                'common' => [
                    'version' => 'tor nani',
                ],
            ],
        ]);
    }
}
