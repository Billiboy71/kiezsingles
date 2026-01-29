<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DistrictPostcodeController extends Controller
{
    public function index(Request $request, string $district)
    {
        $postcodes = DB::table('district_postcodes')
            ->where('district', $district)
            ->orderBy('postcode')
            ->pluck('postcode');

        return response()->json([
            'district' => $district,
            'postcodes' => $postcodes,
        ]);
    }
}
