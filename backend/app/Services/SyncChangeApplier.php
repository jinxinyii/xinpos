<?php

namespace App\Services;

use App\Models\Business;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SyncChangeApplier
{
    /** @param array<string, mixed> $change */
    public function apply(Business $business, array $change): void
    {
        $payload = $change['payload'];

        match ($change['entityType']) {
            'category' => $this->applyCategory($business, $change['entityId'], $payload),
            'product' => $this->applyProduct($business, $change['entityId'], $payload),
            'inventory_movement' => $this->applyInventoryMovement($business, $change['entityId'], $payload),
            default => throw ValidationException::withMessages([
                'changes' => ["Unsupported entity type: {$change['entityType']}"],
            ]),
        };
    }

    /** @param array<string, mixed> $payload */
    private function applyCategory(Business $business, string $id, array $payload): void
    {
        $existing = DB::table('categories')->where('id', $id)->where('business_id', $business->id)->first();
        if ($existing === null && ! isset($payload['name'])) {
            throw ValidationException::withMessages(['changes' => ['New categories require a name.']]);
        }

        DB::table('categories')->updateOrInsert(
            ['id' => $id, 'business_id' => $business->id],
            [
                'name' => $payload['name'] ?? $existing->name,
                'description' => $payload['description'] ?? ($existing->description ?? null),
                'is_active' => $payload['isActive'] ?? ($existing->is_active ?? true),
                'updated_at' => now(),
                'created_at' => now(),
            ],
        );
    }

    /** @param array<string, mixed> $payload */
    private function applyProduct(Business $business, string $id, array $payload): void
    {
        $existing = DB::table('products')->where('id', $id)->where('business_id', $business->id)->first();
        if ($existing === null && ! isset($payload['name'], $payload['costPriceCentavos'], $payload['sellingPriceCentavos'])) {
            throw ValidationException::withMessages(['changes' => ['New products require complete data.']]);
        }

        DB::table('products')->updateOrInsert(
            ['id' => $id, 'business_id' => $business->id],
            [
                'category_id' => $payload['categoryId'] ?? ($existing->category_id ?? null),
                'name' => $payload['name'] ?? $existing->name,
                'sku' => $payload['sku'] ?? ($existing->sku ?? null),
                'description' => $payload['description'] ?? ($existing->description ?? null),
                'cost_price_centavos' => $payload['costPriceCentavos'] ?? $existing->cost_price_centavos,
                'selling_price_centavos' => $payload['sellingPriceCentavos'] ?? $existing->selling_price_centavos,
                'reorder_level' => $payload['reorderLevel'] ?? ($existing->reorder_level ?? 0),
                'track_inventory' => $payload['trackInventory'] ?? ($existing->track_inventory ?? true),
                'is_active' => $payload['isActive'] ?? ($existing->is_active ?? true),
                'updated_at' => now(),
                'created_at' => now(),
            ],
        );
    }

    /** @param array<string, mixed> $payload */
    private function applyInventoryMovement(Business $business, string $id, array $payload): void
    {
        if (! isset($payload['productId'], $payload['movementType'], $payload['quantityDelta'])) {
            throw ValidationException::withMessages(['changes' => ['Inventory movements require complete data.']]);
        }
        $product = DB::table('products')
            ->where('id', $payload['productId'])
            ->where('business_id', $business->id)
            ->first();
        if ($product === null) {
            throw ValidationException::withMessages(['changes' => ['Inventory movement product was not found.']]);
        }

        DB::table('inventory_movements')->updateOrInsert(
            ['id' => $id, 'business_id' => $business->id],
            [
                'product_id' => $payload['productId'],
                'product_name_snapshot' => $payload['productNameSnapshot'] ?? $product->name,
                'movement_type' => $payload['movementType'],
                'quantity_delta' => $payload['quantityDelta'],
                'reference_type' => $payload['referenceType'] ?? null,
                'reference_id' => $payload['referenceId'] ?? null,
                'note' => $payload['note'] ?? null,
                'occurred_at' => Carbon::createFromTimestampMs($payload['createdAt'] ?? now()->valueOf()),
                'updated_at' => now(),
                'created_at' => now(),
            ],
        );
    }
}
