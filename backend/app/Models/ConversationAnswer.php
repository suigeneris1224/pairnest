<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ConversationAnswer extends Model
{
    protected $fillable = ['conversation_prompt_id', 'user_id', 'answer'];

    public function prompt(): BelongsTo
    {
        return $this->belongsTo(ConversationPrompt::class, 'conversation_prompt_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
