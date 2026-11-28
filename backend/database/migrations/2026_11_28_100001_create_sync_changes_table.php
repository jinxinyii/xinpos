<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sync_changes', function (Blueprint $table): void {
            $table->id();
            $table->foreignUuid('business_id')->constrained('businesses')->cascadeOnDelete();
            $table->uuid('client_change_id')->unique();
            $table->string('entity_type', 80);
            $table->string('entity_id', 120);
            $table->string('operation', 16);
            $table->json('payload');
            $table->timestamp('client_created_at')->nullable();
            $table->timestamps();
            $table->index(['business_id', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sync_changes');
    }
};
