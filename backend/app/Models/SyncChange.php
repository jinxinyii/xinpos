<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SyncChange extends Model
{
    protected $fillable = [
        'business_id',
        'client_change_id',
        'entity_type',
        'entity_id',
        'operation',
        'payload',
        'client_created_at',
    ];

    protected function casts(): array
    {
        return ['payload' => 'array', 'client_created_at' => 'datetime'];
    }

    public function business(): BelongsTo
    {
        return $this->belongsTo(Business::class);
    }
}
