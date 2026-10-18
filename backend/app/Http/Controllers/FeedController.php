<?php

namespace App\Http\Controllers;

use App\Models\GoalContribution;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

/**
 * What your partner has been up to: the notification bell's feed.
 */
class FeedController extends Controller
{
    private const LIMIT = 30;

    public function __invoke(Request $request): JsonResponse
    {
        $me = $request->user();
        $couple = $me->couple;
        $notMe = fn ($q) => $q->where('user_id', '!=', $me->id);

        $items = new Collection;

        // Transfers are announced by their goal contribution below.
        foreach ($couple->transactions()->tap($notMe)->where('type', 'release')->with('user:id,name', 'goal:id,name')->latest()->limit(self::LIMIT)->get() as $t) {
            $items->push($this->item('goal', $t->user->name, "{$t->user->name} cancelled {$t->goal?->name}", 'Savings released', $t->amount, $t->created_at));
        }

        foreach ($couple->transactions()->tap($notMe)->whereIn('type', ['expense', 'income'])->with('user:id,name')->latest()->limit(self::LIMIT)->get() as $t) {
            $items->push($this->item(
                $t->type === 'income' ? 'income' : 'expense',
                $t->user->name,
                $t->type === 'income' ? "{$t->user->name} added income" : "{$t->user->name} added an expense",
                $t->title,
                $t->amount,
                $t->created_at,
            ));
        }

        // Top-ups into shared wallets.
        foreach ($couple->transactions()->tap($notMe)->where('type', 'move')->whereNotNull('to_wallet_id')
            ->whereIn('to_wallet_id', $couple->wallets()->whereNull('user_id')->select('id'))
            ->with('user:id,name', 'toWallet:id,name')->latest()->limit(self::LIMIT)->get() as $t) {
            $items->push($this->item('topup', $t->user->name, "{$t->user->name} topped up {$t->toWallet?->name}", null, $t->amount, $t->created_at));
        }

        $contributions = GoalContribution::query()
            ->whereIn('goal_id', $couple->goals()->select('id'))
            ->tap($notMe)
            ->with('user:id,name', 'goal:id,name')
            ->latest()->limit(self::LIMIT)->get();
        foreach ($contributions as $c) {
            $items->push($this->item('goal', $c->user->name, "{$c->user->name} saved toward {$c->goal->name}", null, $c->amount, $c->created_at));
        }

        // Private check-ins never leave their author.
        foreach ($couple->moods()->tap($notMe)->where('is_private', false)->with('user:id,name')->latest()->limit(self::LIMIT)->get() as $m) {
            $items->push($this->item('mood', $m->user->name, "{$m->user->name} is feeling {$m->mood}", $m->note ?: null, null, $m->created_at));
        }

        foreach ($couple->answers()->tap($notMe)->with('user:id,name', 'prompt')->latest()->limit(self::LIMIT)->get() as $a) {
            $items->push($this->item('talk', $a->user->name, "{$a->user->name} answered this week's Money Talk", $a->prompt?->question, null, $a->updated_at));
        }

        foreach ($couple->settlements()->where('from_user_id', '!=', $me->id)->with('from:id,name')->latest()->limit(self::LIMIT)->get() as $s) {
            $items->push($this->item('settle', $s->from->name, "{$s->from->name} settled up with you", null, $s->amount, $s->created_at));
        }

        return response()->json($items->sortByDesc('at')->take(self::LIMIT)->values());
    }

    private function item(string $type, string $userName, string $title, ?string $subtitle, ?float $amount, $at): array
    {
        return [
            'type' => $type,
            'user_name' => $userName,
            'title' => $title,
            'subtitle' => $subtitle,
            'amount' => $amount,
            'at' => $at?->toIso8601ZuluString(),
        ];
    }
}
