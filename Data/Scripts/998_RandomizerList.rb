#===============================================================================
# Script: 998_RandomizerList.rb
# Descrizione: Esporta automaticamente tutti i Pokémon presenti nelle varie aree
#              secondo il Randomizer Wild Pokémon -> Area in "randomizer_encounters.txt"
#              e "randomizer_data.js", e traccia la posizione attuale in "current_location.js"
#              subito dopo che il salvataggio è stato effettivamente caricato.
#===============================================================================

# Funzione di logging sicura che non causa mai crash anche se il debug console non è pronto
def randomizer_log(msg)
  begin
    if defined?(echoln)
      echoln(msg)
    elsif defined?(echo)
      echo("#{msg}\r\n")
    end
  rescue
  end
end

# Serializzatore JSON leggero e autonomo (zero dipendenze, sicuro al 100%)
def randomizer_json_serialize(obj)
  case obj
  when String
    obj.dump
  when Symbol
    obj.to_s.dump
  when Integer, Float
    obj.to_s
  when TrueClass
    "true"
  when FalseClass
    "false"
  when NilClass
    "null"
  when Array
    "[" + obj.map { |e| randomizer_json_serialize(e) }.join(",") + "]"
  when Hash
    "{" + obj.map { |k, v| "#{k.to_s.dump}:#{randomizer_json_serialize(v)}" }.join(",") + "}"
  else
    obj.to_s.dump
  end
end

# Funzione di supporto per convertire il Map ID nel vero nome della mappa
def randomizer_get_map_name(map_id)
  name = nil
  begin
    name = pbGetMapNameFromId(map_id)
    return name if name && !name.empty?
  rescue
  end

  begin
    name = pbGetBasicMapNameFromId(map_id)
    return name if name && !name.empty?
  rescue
  end

  begin
    if defined?(getMapName)
      name = getMapName(map_id)
      return name if name && !name.empty? && name != "Unknown location"
    end
  rescue
  end

  return nil
end

# Aggiorna il micro-file current_location.js con la mappa attuale per la web app
def randomizer_update_current_location(map_id)
  return if !map_id
  map_name = randomizer_get_map_name(map_id) || "Mappa #{map_id}"
  begin
    loc_data = {
      "map_id" => map_id,
      "map_name" => map_name,
      "timestamp" => Time.now.to_i
    }
    File.open("current_location.js", "w:UTF-8") do |f|
      f.puts "window.CURRENT_LOCATION = " + randomizer_json_serialize(loc_data) + ";"
    end
  rescue
  end
end

# Funzione principale per l'esportazione degli incontri (completamente silenziosa, nessun pbMessage)
def export_randomizer_encounters
  output_txt  = "randomizer_encounters.txt"
  output_data = "randomizer_data.js"

  if !defined?(GameData::EncounterRandom)
    randomizer_log("[Randomizer Export] GameData::EncounterRandom non e' definito.")
    return
  end

  # Se i dati non sono ancora stati caricati in memoria, tenta il caricamento da dat
  if GameData::EncounterRandom::DATA.nil? || GameData::EncounterRandom::DATA.empty?
    randomizer_log("[Randomizer Export] GameData::EncounterRandom::DATA e' vuoto. Tento il caricamento...")
    begin
      GameData::EncounterRandom.load
    rescue => e
      randomizer_log("[Randomizer Export] Errore durante EncounterRandom.load: #{e.message}")
    end
  end

  data = GameData::EncounterRandom::DATA
  if data.nil? || data.empty?
    randomizer_log("[Randomizer Export] Nessun dato trovato in GameData::EncounterRandom::DATA.")
    return
  end

  # Recupero impostazioni e stato del salvataggio attualmente caricato
  switch_wild_id   = defined?(SWITCH_RANDOM_WILD) ? SWITCH_RANDOM_WILD : 778
  switch_area_id   = defined?(SWITCH_RANDOM_WILD_AREA) ? SWITCH_RANDOM_WILD_AREA : 777
  switch_fusion_id = defined?(SWITCH_RANDOM_WILD_TO_FUSION) ? SWITCH_RANDOM_WILD_TO_FUSION : 953

  is_wild_random   = $game_switches ? $game_switches[switch_wild_id] : false
  is_area_random   = $game_switches ? $game_switches[switch_area_id] : false
  is_fusion_random = $game_switches ? $game_switches[switch_fusion_id] : false
  trainer_name     = ($Trainer && $Trainer.name) ? $Trainer.name : "Giocatore"
  export_timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')

  json_payload = {
    "trainer" => trainer_name,
    "export_date" => export_timestamp,
    "wild_random" => is_wild_random,
    "area_random" => is_area_random,
    "fusion_random" => is_fusion_random,
    "maps" => {}
  }

  begin
    File.open(output_txt, "w:UTF-8") do |file|
      file.puts "============================================================"
      file.puts "  POKEMON INFINITE FUSION - INCONTRI RANDOMIZER (AREA)"
      file.puts "============================================================"
      file.puts "Salvataggio caricato per: #{trainer_name}"
      file.puts "Wild Pokemon Randomizer:  #{is_wild_random ? 'ATTIVO' : 'NON ATTIVO'}"
      file.puts "Modalita' Wild Pokemon:   #{is_area_random ? 'Area (Per Percorso)' : 'Globale / Vanilla'}"
      file.puts "Fusioni selvatiche:       #{is_fusion_random ? 'SI' : 'NO'}"
      file.puts "Data esportazione:        #{export_timestamp}"
      file.puts "============================================================"
      file.puts ""

      # Ordina le mappe in modo sequenziale per Map ID
      sorted_encounters = data.values.compact.sort_by do |enc|
        [enc.map || 0, enc.version || 0]
      end

      total_maps = 0

      sorted_encounters.each do |enc_data|
        next if enc_data.types.nil? || enc_data.types.empty?

        # Controlla se la mappa contiene effettivamente incontri definiti
        has_encounters = enc_data.types.values.any? { |list| list && !list.empty? }
        next unless has_encounters

        map_id = enc_data.map
        map_name = randomizer_get_map_name(map_id)
        display_map_name = map_name || "Mappa #{map_id}"

        json_payload["maps"][map_id.to_s] = {
          "id" => map_id,
          "name" => display_map_name,
          "encounters" => {}
        }

        file.puts "========================================"
        if map_name
          file.puts "MAP ID: #{map_id} - #{map_name}"
        else
          file.puts "MAP ID: #{map_id}"
        end
        file.puts "========================================"

        enc_data.types.each do |encounter_type, pokemon_list|
          next if pokemon_list.nil? || pokemon_list.empty?

          file.puts ""
          file.puts "Tipo: #{encounter_type}"

          # Deduplicazione per specie e aggregazione livelli min/max
          species_data = {}
          species_order = []

          pokemon_list.each do |encounter|
            next if encounter.nil?
            species = encounter[1]
            next if species.nil?

            min_lvl = encounter[2] ? encounter[2].to_i : 1
            max_lvl = encounter[3] ? encounter[3].to_i : min_lvl
            min_lvl, max_lvl = [min_lvl, max_lvl].min, [min_lvl, max_lvl].max

            if species_data[species]
              species_data[species][:min] = [species_data[species][:min], min_lvl].min
              species_data[species][:max] = [species_data[species][:max], max_lvl].max
            else
              species_order << species
              species_data[species] = { min: min_lvl, max: max_lvl }
            end
          end

          json_type_list = []

          species_order.each do |species|
            info = species_data[species]
            min_lvl = info[:min]
            max_lvl = info[:max]

            sp_obj = nil
            begin
              sp_obj = GameData::Species.get(species)
            rescue
            end

            pokemon_name = sp_obj ? sp_obj.name : species.to_s
            dex_num = (sp_obj && sp_obj.id_number) ? sp_obj.id_number : 0
            t1 = (sp_obj && sp_obj.type1) ? sp_obj.type1.to_s : "NORMAL"
            t2 = (sp_obj && sp_obj.type2 && sp_obj.type2 != sp_obj.type1) ? sp_obj.type2.to_s : nil
            species_str = species.to_s

            json_type_list << {
              "species" => species_str,
              "name" => pokemon_name,
              "dex_number" => dex_num,
              "type1" => t1,
              "type2" => t2,
              "min_lvl" => min_lvl,
              "max_lvl" => max_lvl,
              "icon" => "Graphics/Pokemon/Icons/#{species_str}.png"
            }

            if min_lvl == max_lvl
              file.puts "- #{pokemon_name} (Lv #{min_lvl})"
            else
              file.puts "- #{pokemon_name} (Lv #{min_lvl}-#{max_lvl})"
            end
          end

          json_payload["maps"][map_id.to_s]["encounters"][encounter_type.to_s] = json_type_list
        end

        file.puts ""
        total_maps += 1
      end

      file.puts "============================================================"
      file.puts "Totale mappe con incontri esportate: #{total_maps}"
      file.puts "============================================================"
    end

    $randomizer_encounters_exported = true
    randomizer_log("[Randomizer Export] Incontri esportati con successo in #{output_txt}.")

    # Esporta randomizer_data.js per l'interfaccia Pokédex interattiva
    begin
      File.open(output_data, "w:UTF-8") do |f|
        f.puts "window.RANDOMIZER_DATA = " + randomizer_json_serialize(json_payload) + ";"
      end
      randomizer_log("[Randomizer Export] Dati interattivi esportati in #{output_data}.")
    rescue => err_js
      randomizer_log("[Randomizer Export] Errore salvataggio #{output_data}: #{err_js.message}")
    end

    # Scrivi la posizione iniziale per il Pokédex interattivo
    initial_map = ($game_map && $game_map.map_id) ? $game_map.map_id : 1
    randomizer_update_current_location(initial_map)

  rescue => e
    randomizer_log("[Randomizer Export] ERRORE durante la scrittura del file: #{e.message}\n#{e.backtrace.join("\n")}")
  ensure
    # Assicura sempre che lo stato dei messaggi non rimanga attivo e non blocchi gli input di gioco
    if defined?($game_temp) && $game_temp
      $game_temp.message_window_showing = false
    end
  end
end

#===============================================================================
# Hook automatico: Caricamento del salvataggio
#===============================================================================
# onLoadExistingGame viene definito in 052_InfiniteFusion/System/MultiSaves.rb
# e chiamato al termine di Game.load(save_data) in 003_Game processing/001_StartGame.rb.
# Poiché 998_RandomizerList.rb è nella root di Data/Scripts, viene caricato prima.
# Intercettiamo la definizione di onLoadExistingGame, installiamo l'hook e ripristiniamo
# immediatamente method_added senza lasciare tracce nel runtime.
#===============================================================================
module RandomizerHookManager
  @hooked = false

  def self.install_hook
    return if @hooked
    return unless defined?(onLoadExistingGame)
    @hooked = true
    Object.class_eval do
      alias onLoadExistingGame_randomizer_export onLoadExistingGame
      def onLoadExistingGame
        onLoadExistingGame_randomizer_export
        begin
          export_randomizer_encounters
        rescue => e
          randomizer_log("[Randomizer Export] Errore durante l'hook: #{e.message}")
        end

        # Registra il listener per il tracciamento della posizione in tempo reale
        begin
          if defined?(Events) && defined?(Events.onMapChange) && !$randomizer_map_change_hooked
            $randomizer_map_change_hooked = true
            Events.onMapChange += proc { |sender, prevMap|
              begin
                if $game_map && $game_map.map_id
                  randomizer_update_current_location($game_map.map_id)
                end
              rescue
              end
            }
            randomizer_log("[Randomizer Export] Hook Events.onMapChange registrato per posizione live.")
          end
        rescue => err_ev
          randomizer_log("[Randomizer Export] Impossibile registrare onMapChange: #{err_ev.message}")
        end

        # Registra il listener per il log diagnostico degli incontri selvatici reali
        begin
          if defined?(Events) && defined?(Events.onWildPokemonCreate) && !$randomizer_wild_create_hooked
            $randomizer_wild_create_hooked = true
            Events.onWildPokemonCreate += proc { |_sender, pkmn|
              begin
                File.open("last_encounter_log.txt", "a:UTF-8") do |f|
                  f.puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] Map: #{$game_map ? $game_map.map_id : 'nil'} | Species: #{pkmn.species} (#{pkmn.name rescue ''}) Lv: #{pkmn.level rescue ''} | Fused: #{pkmn.isFusion? rescue false}"
                end
              rescue
              end
            }
          end
        rescue => err_wc
        end
      end
    end
    randomizer_log("[Randomizer Export] Hook onLoadExistingGame installato con successo.")
  end
end

if defined?(onLoadExistingGame)
  RandomizerHookManager.install_hook
else
  class << Object
    alias __orig_method_added_randomizer method_added rescue nil
    def method_added(mid)
      __orig_method_added_randomizer(mid) if respond_to?(:__orig_method_added_randomizer, true)
      if mid.to_sym == :onLoadExistingGame
        class << Object
          if respond_to?(:__orig_method_added_randomizer, true)
            alias method_added __orig_method_added_randomizer
            remove_method :__orig_method_added_randomizer rescue nil
          else
            remove_method :method_added rescue nil
          end
        end
        RandomizerHookManager.install_hook rescue nil
      end
    end
  end
end


