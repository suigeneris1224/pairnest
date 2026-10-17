<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A private profile photo, visible only to the couple.
        Schema::table('users', function (Blueprint $table) {
            $table->string('avatar_path')->nullable()->after('profile');
            $table->timestamp('avatar_updated_at')->nullable()->after('avatar_path');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['avatar_path', 'avatar_updated_at']);
        });
    }
};
