<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DistrictPostcodesSeeder extends Seeder
{
    public function run(): void
    {
        // HIER kommen die berechneten / finalen Daten rein
        // Beispiel Berlin (gekürzt – bitte später vollständig ersetzen)
        $data = [
            'Mitte' => [
                '10115', '10117', '10119', '10178', '10179',
            ],
            'Friedrichshain-Kreuzberg' => [
                '10243', '10245', '10247', '10249',
                '10961', '10963', '10965', '10967', '10969',
            ],
            'Treptow-Köpenick' => [
                '12435', '12437', '12439',
                '12524', '12526', '12527',
                '12555', '12557', '12559',
            ],
        ];

        $rows = [];
        $now = now();

        foreach ($data as $district => $postcodes) {
            foreach ($postcodes as $postcode) {
                $rows[] = [
                    'district'   => $district,
                    'postcode'   => $postcode,
                    'created_at'=> $now,
                    'updated_at'=> $now,
                ];
            }
        }

        // sauber neu befüllen
        DB::table('district_postcodes')->truncate();
        DB::table('district_postcodes')->insert($rows);
    }
}
