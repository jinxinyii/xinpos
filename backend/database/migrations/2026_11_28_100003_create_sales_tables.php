<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sales', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('business_id')->constrained('businesses')->cascadeOnDelete();
            $table->string('receipt_number')->unique();
            $table->string('status', 32)->default('completed');
            $table->unsignedInteger('subtotal_centavos');
            $table->unsignedInteger('discount_centavos')->default(0);
            $table->unsignedInteger('total_centavos');
            $table->timestamp('sold_at');
            $table->timestamps();
            $table->index(['business_id', 'sold_at']);
        });

        Schema::create('sale_items', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('sale_id')->constrained('sales')->cascadeOnDelete();
            $table->foreignUuid('product_id')->nullable()->constrained('products')->nullOnDelete();
            $table->string('product_name', 150);
            $table->string('sku')->nullable();
            $table->unsignedInteger('quantity');
            $table->unsignedInteger('unit_price_centavos');
            $table->unsignedInteger('unit_cost_centavos');
            $table->unsignedInteger('line_total_centavos');
            $table->timestamps();
        });

        Schema::create('payments', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('sale_id')->constrained('sales')->cascadeOnDelete();
            $table->string('method', 32);
            $table->unsignedInteger('amount_centavos');
            $table->unsignedInteger('amount_tendered_centavos')->nullable();
            $table->string('reference_number')->nullable();
            $table->timestamp('paid_at');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payments');
        Schema::dropIfExists('sale_items');
        Schema::dropIfExists('sales');
    }
};
