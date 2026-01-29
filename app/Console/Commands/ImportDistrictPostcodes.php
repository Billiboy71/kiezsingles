<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class ImportDistrictPostcodes extends Command
{
    protected $signature = 'district-postcodes:import {csv : Pfad zur CSV-Datei (z.B. storage/app/district_postcodes.csv)}';
    protected $description = 'Importiert District-Postcode-Zuordnungen aus einer CSV-Datei (ersetzt vollständig)';

    public function handle(): int
    {
        $inputPath = (string) $this->argument('csv');

        // Pfad normalisieren (Windows)
        $inputPath = str_replace('\\', '/', $inputPath);

        // 1) Direkt so wie angegeben
        $csvPath = $inputPath;

        // 2) Falls relativ: auf Projekt-Root beziehen
        if (!is_file($csvPath)) {
            $try = base_path($inputPath);
            if (is_file($try)) {
                $csvPath = $try;
            }
        }

        // 3) Falls "storage/app/..." angegeben: auch storage_path versuchen
        if (!is_file($csvPath) && str_starts_with($inputPath, 'storage/app/')) {
            $try = storage_path('app/' . substr($inputPath, strlen('storage/app/')));
            if (is_file($try)) {
                $csvPath = $try;
            }
        }

        if (!is_file($csvPath)) {
            $this->error("CSV-Datei nicht gefunden: {$inputPath}");
            $this->line("Tipp: Lege sie z.B. hier ab: " . storage_path('app/district_postcodes.csv'));
            return self::FAILURE;
        }

        if (!Schema::hasTable('district_postcodes')) {
            $this->error("Tabelle district_postcodes existiert nicht.");
            return self::FAILURE;
        }

        $handle = fopen($csvPath, 'r');
        if ($handle === false) {
            $this->error("CSV-Datei kann nicht geöffnet werden: {$csvPath}");
            return self::FAILURE;
        }

        $header = fgetcsv($handle);
        if ($header === false) {
            fclose($handle);
            $this->error("CSV ist leer: {$csvPath}");
            return self::FAILURE;
        }

        // trim + BOM entfernen
        $header = array_map(static function ($h) {
            $h = trim((string) $h);
            // UTF-8 BOM am Anfang entfernen
            $h = preg_replace('/^\xEF\xBB\xBF/', '', $h);
            return $h;
        }, $header);

        $expected = ['district', 'postcode'];

        if ($header !== $expected) {
            fclose($handle);
            $this->error("Ungültiger CSV-Header. Erwartet: district,postcode | Gefunden: " . implode(',', $header));
            return self::FAILURE;
        }

        $rows = [];
        $now = now();
        $line = 1;

        while (($data = fgetcsv($handle)) !== false) {
            $line++;

            if (count($data) < 2) {
                $this->warn("Zeile {$line} übersprungen (zu wenig Spalten).");
                continue;
            }

            $district = trim((string) $data[0]);
            $postcode = trim((string) $data[1]);

            if ($district === '' || $postcode === '') {
                $this->warn("Zeile {$line} übersprungen (leer).");
                continue;
            }

            if (!preg_match('/^\d{5}$/', $postcode)) {
                $this->warn("Zeile {$line} übersprungen (ungültige PLZ: {$postcode}).");
                continue;
            }

            $rows[] = [
                'district'   => $district,
                'postcode'   => $postcode,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        fclose($handle);

        if (empty($rows)) {
            $this->error("Keine gültigen Datensätze gefunden.");
            return self::FAILURE;
        }

        DB::transaction(function () use ($rows) {
            DB::table('district_postcodes')->truncate();

            foreach (array_chunk($rows, 1000) as $chunk) {
                DB::table('district_postcodes')->insert($chunk);
            }
        });

        $this->info(count($rows) . " Datensätze importiert.");
        $this->line("Quelle: {$csvPath}");

        return self::SUCCESS;
    }
}
