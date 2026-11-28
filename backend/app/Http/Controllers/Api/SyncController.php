<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Business;
use App\Models\SyncChange;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SyncController extends Controller
{
    public function batch(Request $request): JsonResponse
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

        DB::transaction(function () use ($data, $request, &$acceptedIds): void {
            foreach ($data['changes'] as $change) {
                $businessId = $change['payload']['businessId'] ?? null;
                $business = is_string($businessId)
                    ? Business::where('id', $businessId)->where('owner_id', $request->user()->id)->first()
                    : null;

                if (! $business) {
                    abort(403, 'The change does not belong to one of your businesses.');
                }

                SyncChange::firstOrCreate(
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
                $acceptedIds[] = $change['id'];
            }
        });

        return response()->json(['acceptedIds' => $acceptedIds]);
    }
}
