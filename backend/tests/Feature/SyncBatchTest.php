<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SyncBatchTest extends TestCase
{
    use RefreshDatabase;

    public function test_an_owner_can_submit_an_idempotent_sync_batch(): void
    {
        $registration = $this->postJson('/api/auth/register', [
            'name' => 'Owner',
            'email' => 'owner@example.test',
            'password' => 'correct-horse-battery-staple',
            'device_name' => 'xinPOS test device',
            'business_name' => 'Test Store',
        ])->assertCreated();

        $token = $registration->json('token');
        $businessId = $registration->json('business.id');
        $this->postJson('/api/auth/login', [
            'email' => 'owner@example.test',
            'password' => 'correct-horse-battery-staple',
            'device_name' => 'second xinPOS test device',
        ])->assertOk()
            ->assertJsonPath('business.id', $businessId);
        $change = [
            'id' => 'ab2b0f8a-238a-49c0-8423-34d42d17e992',
            'entityType' => 'product',
            'entityId' => 'a9fae8ad-afdb-49dc-98ce-29d7ef6a4f22',
            'operation' => 'upsert',
            'createdAt' => 1795860000000,
            'payload' => [
                'businessId' => $businessId,
                'name' => 'Iced tea',
                'sku' => 'TEA-001',
                'costPriceCentavos' => 1000,
                'sellingPriceCentavos' => 1500,
                'reorderLevel' => 0,
                'trackInventory' => true,
                'isActive' => true,
            ],
        ];

        $this->withToken($token)
            ->postJson('/api/sync/batch', ['changes' => [$change]])
            ->assertOk()
            ->assertJsonPath('acceptedIds.0', $change['id']);

        $this->withToken($token)
            ->postJson('/api/sync/batch', ['changes' => [$change]])
            ->assertOk();

        $this->assertDatabaseCount('sync_changes', 1);
        $this->assertDatabaseHas('products', [
            'id' => $change['entityId'],
            'business_id' => $businessId,
            'sku' => 'TEA-001',
        ]);
        $this->withToken($token)
            ->getJson("/api/sync/changes?business_id={$businessId}")
            ->assertOk()
            ->assertJsonPath('changes.0.id', $change['id'])
            ->assertJsonPath('changes.0.payload.name', 'Iced tea');

        $sale = [
            'id' => '5aa7f6a3-e9c9-4d1c-b02a-84588756dd6b',
            'entityType' => 'sale',
            'entityId' => 'd41b6ec8-d1db-4658-b9fb-05d3c4ee6be7',
            'operation' => 'create',
            'createdAt' => 1795860001000,
            'payload' => [
                'businessId' => $businessId,
                'receiptNumber' => 'XPOS-TEST-001',
                'status' => 'completed',
                'subtotalCentavos' => 3000,
                'discountCentavos' => 0,
                'totalCentavos' => 3000,
                'soldAt' => 1795860001000,
                'createdAt' => 1795860001000,
                'updatedAt' => 1795860001000,
                'items' => [[
                    'id' => 'eeb1654e-801e-4b57-9e3b-7e2a1cd8a046',
                    'productId' => $change['entityId'],
                    'productName' => 'Iced tea',
                    'sku' => 'TEA-001',
                    'quantity' => 2,
                    'unitPriceCentavos' => 1500,
                    'unitCostCentavos' => 1000,
                    'lineTotalCentavos' => 3000,
                ]],
                'payment' => [
                    'id' => '471218cf-0e18-41ae-8ea3-388811d6e271',
                    'method' => 'cash',
                    'amountCentavos' => 3000,
                    'amountTenderedCentavos' => 3000,
                    'paidAt' => 1795860001000,
                ],
                'inventoryMovements' => [[
                    'id' => 'd06e7e55-cd17-4957-b09e-8898501423fd',
                    'productId' => $change['entityId'],
                    'productNameSnapshot' => 'Iced tea',
                    'movementType' => 'sale',
                    'quantityDelta' => -2,
                    'referenceType' => 'sale',
                    'referenceId' => 'd41b6ec8-d1db-4658-b9fb-05d3c4ee6be7',
                    'createdAt' => 1795860001000,
                ]],
            ],
        ];
        $this->withToken($token)
            ->postJson('/api/sync/batch', ['changes' => [$sale]])
            ->assertOk()
            ->assertJsonPath('acceptedIds.0', $sale['id']);
        $this->withToken($token)
            ->postJson('/api/sync/batch', ['changes' => [$sale]])
            ->assertOk();

        $this->assertDatabaseHas('sales', ['id' => $sale['entityId'], 'business_id' => $businessId]);
        $this->assertDatabaseCount('sale_items', 1);
        $this->assertDatabaseCount('payments', 1);
        $this->assertDatabaseHas('inventory_movements', ['id' => $sale['payload']['inventoryMovements'][0]['id']]);
    }
}
