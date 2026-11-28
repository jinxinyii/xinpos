<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Business;
use App\Models\SyncChange;
use App\Services\SyncChangeApplier;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SyncController extends Controller
{
    public function changes(Request $request): JsonResponse
    {
        $data = $request->validate([
            'business_id' => ['required', 'uuid'],
            'cursor' => ['nullable', 'integer', 'min:0'],
        ]);
        $business = Business::query()
            ->where('id', $data['business_id'])
            ->where('owner_id', $request->user()->id)
            ->firstOrFail();
        $cursor = $data['cursor'] ?? 0;
        $changes = SyncChange::query()
            ->where('business_id', $business->id)
            ->where('id', '>', $cursor)
            ->orderBy('id')
            ->limit(100)
            ->get();

        return response()->json([
            'changes' => $changes->map(fn (SyncChange $change): array => [
                'cursor' => $change->id,
                'id' => $change->client_change_id,
                'entityType' => $change->entity_type,
                'entityId' => $change->entity_id,
                'operation' => $change->operation,
                'payload' => $change->payload,
                'createdAt' => $change->client_created_at?->valueOf(),
            ]),
            'nextCursor' => $changes->last()?->id ?? $cursor,
        ]);
    }

    public function batch(Request $request, SyncChangeApplier $applier): JsonResponse
    {
        $data = $request->validate([
            'changes' => ['required', 'array', 'min:1', 'max:100'],
            'changes.*.id' => ['required', 'uuid'],
            'changes.*.entityType' => ['required', 'string', 'max:80'],
            'changes.*.entityId' => ['required', 'string', 'max:120'],
            'changes.*.operation' => ['required', 'in:create,upsert,delete'],
            'changes.*.payload' => ['required', 'array'],
            'changes.*.createdAt' => ['nullable', 'integer'],
        ]);
        $acceptedIds = [];

        DB::transaction(function () use ($data, $request, $applier, &$acceptedIds): void {
            foreach ($data['changes'] as $change) {
                $businessId = $change['payload']['businessId'] ?? null;
                $business = is_string($businessId)
                    ? Business::where('id', $businessId)->where('owner_id', $request->user()->id)->first()
                    : null;

                if (! $business) {
                    abort(403, 'The change does not belong to one of your businesses.');
                }

                $syncChange = SyncChange::firstOrCreate(
                    ['client_change_id' => $change['id']],
                    [
                        'business_id' => $business->id,
                        'entity_type' => $change['entityType'],
                        'entity_id' => $change['entityId'],
                        'operation' => $change['operation'],
                        'payload' => $change['payload'],
                        'client_created_at' => isset($change['createdAt'])
                            ? Carbon::createFromTimestampMs($change['createdAt'])
                            : null,
                    ],
                );
                if ($syncChange->wasRecentlyCreated) {
                    $applier->apply($business, $change);
                }
                $acceptedIds[] = $change['id'];
            }
        });

        return response()->json(['acceptedIds' => $acceptedIds]);
    }
}
