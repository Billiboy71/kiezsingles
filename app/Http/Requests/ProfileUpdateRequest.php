<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Requests\ProfileUpdateRequest.php
// Changed: 10-03-2026 01:12 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Http\Requests;

use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ProfileUpdateRequest extends FormRequest
{
    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'username' => ['required', 'string', 'min:4', 'max:20', 'regex:/^[a-zA-Z0-9._-]+$/', Rule::unique(User::class)->ignore($this->user()->id)],
            'email' => [
                'required',
                'string',
                'lowercase',
                'email',
                'max:255',
                Rule::unique(User::class)->ignore($this->user()->id),
            ],
        ];
    }
}