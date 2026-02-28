<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\File;

class Language extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name',
        'native_name',
        'translations',
        'hash',
    ];

    protected $casts = [
        'translations' => 'array',
    ];

    // Auto-calculate hash on save
    protected static function boot()
    {
        parent::boot();

        static::saving(function ($language) {
            $language->hash = md5(json_encode($language->translations, JSON_PRETTY_PRINT));
        });

        static::saved(function ($language) {
            $language->saveToFile();
        });

        static::deleted(function ($language) {
            $language->deleteFile();
        });
    }

    // Accessor for metadata only (no translations)
    public function getMetadataAttribute()
    {
        return [
            'code' => $this->code,
            'name' => $this->name,
            'nativeName' => $this->native_name,
            'hash' => $this->hash,
            'updatedAt' => $this->updated_at->toIso8601String(),
        ];
    }

    // Save translations to JSON file
    public function saveToFile()
    {
        $path = public_path("translations/{$this->code}.json");
        $content = json_encode($this->translations, JSON_PRETTY_PRINT);
        
        // Ensure directory exists
        if (!File::exists(public_path('translations'))) {
            File::makeDirectory(public_path('translations'), 0755, true);
        }
        
        File::put($path, $content);
    }

    // Delete JSON file
    public function deleteFile()
    {
        $path = public_path("translations/{$this->code}.json");
        if (File::exists($path)) {
            File::delete($path);
        }
    }
}
