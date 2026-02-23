<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_13_232500_add_ticket_draft_columns_to_tickets_table.php
// Purpose: Add admin draft fields to tickets table (reply + internal note).
// Created: 13-02-2026 23:27 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tickets', function (Blueprint $table) {
            // Admin-only drafts (must NOT create ticket messages/events)
            if (!Schema::hasColumn('tickets', 'draft_reply_message')) {
                $table->text('draft_reply_message')->nullable()->after('priority');
            }

            if (!Schema::hasColumn('tickets', 'draft_internal_note')) {
                $table->text('draft_internal_note')->nullable()->after('draft_reply_message');
            }
        });
    }

    public function down(): void
    {
        Schema::table('tickets', function (Blueprint $table) {
            if (Schema::hasColumn('tickets', 'draft_internal_note')) {
                $table->dropColumn('draft_internal_note');
            }

            if (Schema::hasColumn('tickets', 'draft_reply_message')) {
                $table->dropColumn('draft_reply_message');
            }
        });
    }
};
