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
    }
}
