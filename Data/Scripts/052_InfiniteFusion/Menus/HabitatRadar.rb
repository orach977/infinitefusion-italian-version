#===============================================================================
# * RADAR HABITAT & DEX IN-GAME (Next-Level Edition - High Performance)
#===============================================================================
# Autore: Pokemon Infinite Fusion Community & orach977
# Descrizione: Radar avanzato a 512x384 ottimizzato a 60 FPS senza input lag.
# Include cache in memoria, blit diretto da RAM, controlli reattivi (Input.repeat)
# e rimozione delle chiamate I/O ridondanti su disco.
#===============================================================================

class PokemonGlobalMetadata
  attr_accessor :radar_tracked_species
end

class PokemonTemp
  attr_accessor :radar_target_alert
end

#===============================================================================
# Hook sul tracciamento del bersaglio selvatico
#===============================================================================
if defined?(Events) && defined?(Events.onWildPokemonCreate)
  Events.onWildPokemonCreate += proc { |_sender, e|
    pkmn = e[0]
    if $PokemonGlobal && $PokemonGlobal.radar_tracked_species && pkmn
      target = $PokemonGlobal.radar_tracked_species
      target_id = (target.is_a?(Symbol) || target.is_a?(Integer)) ? target : nil
      begin
        target_id ||= GameData::Species.get(target).id
      rescue
        target_id = nil
      end

      if target_id && (pkmn.species == target_id || (pkmn.respond_to?(:species_data) && pkmn.species_data && pkmn.species_data.id == target_id))
        pbSEPlay("shiny") rescue nil
        $PokemonTemp.radar_target_alert = pkmn.name rescue "Pokemon bersaglio"
      end
    end
  }
end

# Hook in battaglia per avviso visivo e sonoro
if defined?(PokeBattle_Battle)
  class PokeBattle_Battle
    unless method_defined?(:_radar_pbStartBattleSendOut)
      alias _radar_pbStartBattleSendOut pbStartBattleSendOut
      def pbStartBattleSendOut(sendOuts)
        _radar_pbStartBattleSendOut(sendOuts)
        if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.radar_target_alert && wildBattle?
          alert_name = $PokemonTemp.radar_target_alert
          $PokemonTemp.radar_target_alert = nil
          pbSEPlay("itemlevel") rescue nil
          pbDisplayPaused(_INTL("TARGET RADAR RILEVATO: {1}!", alert_name))
        end
      end
    end
  end
end

#===============================================================================
# Modulo di supporto dati Habitat Radar con Cache ad alte prestazioni
#===============================================================================
module HabitatRadarData
  @other_maps_cache = {}

  def self.get_encounter_mode
    mode = GameData::Encounter
    if $game_switches && defined?(SWITCH_MODERN_MODE) && $game_switches[SWITCH_MODERN_MODE]
      mode = GameData::EncounterModern if defined?(GameData::EncounterModern)
    end
    if $game_switches && defined?(SWITCH_RANDOM_WILD) && defined?(SWITCH_RANDOM_WILD_AREA) &&
       $game_switches[SWITCH_RANDOM_WILD] && $game_switches[SWITCH_RANDOM_WILD_AREA]
      mode = GameData::EncounterRandom if defined?(GameData::EncounterRandom)
    end
    return mode
  end

  def self.get_map_name(map_id)
    return "Mappa sconosciuta" if map_id.nil?
    name = pbGetMapNameFromId(map_id) rescue nil
    name = pbGetBasicMapNameFromId(map_id) if (name.nil? || name.empty?) rescue nil
    name = "Mappa #{map_id}" if (name.nil? || name.empty?)
    return name
  end

  def self.get_all_encounter_maps
    maps = []
    mode = get_encounter_mode
    data_source = (mode && defined?(mode::DATA) && !mode::DATA.empty?) ? mode::DATA : GameData::Encounter::DATA rescue {}
    data_source.each_value do |enc|
      next if !enc || !enc.map || !enc.types
      has_any = enc.types.values.any? { |slots| slots && !slots.empty? }
      maps << enc.map if has_any
    end
    maps.uniq!
    maps.sort!
    return maps
  end

  def self.encounter_base_label(type)
    t = type.to_s
    case
    when t.start_with?("Land")      then "Erba"
    when t.start_with?("Water")     then "Surf"
    when t == "OldRod"              then "Amo Vecchio"
    when t == "GoodRod"             then "Amo Buono"
    when t == "SuperRod"            then "Super Amo"
    when t.start_with?("Cave")      then "Grotta"
    when t == "RockSmash"           then "Spaccaroccia"
    when t.start_with?("Headbutt")  then "Albero"
    when t == "BugContest"          then "Gara"
    else t
    end
  end

  def self.encounter_time_category(type)
    t = type.to_s
    if t.include?("Morning")
      :morning
    elsif t.include?("Night")
      :night
    elsif t.include?("Evening")
      :evening
    elsif t.include?("Afternoon")
      :afternoon
    elsif t.include?("Day")
      :day
    else
      :any
    end
  end

  def self.encounter_time_label(category)
    case category
    when :morning   then "Mattina"
    when :day       then "Giorno"
    when :afternoon then "Pomeriggio"
    when :evening   then "Sera"
    when :night     then "Notte"
    else "Sempre"
    end
  end

  def self.encounter_type_label(type)
    base = encounter_base_label(type)
    time = encounter_time_label(encounter_time_category(type))
    time == "Sempre" ? base : "#{base} (#{time})"
  end

  def self.encounter_type_symbol(type)
    base = encounter_base_label(type)
    "[#{base}]"
  end

  def self.current_time_category
    return :night     if defined?(PBDayNight) && PBDayNight.isNight?
    return :morning   if defined?(PBDayNight) && PBDayNight.isMorning?
    return :evening   if defined?(PBDayNight) && PBDayNight.isEvening?
    return :afternoon if defined?(PBDayNight) && PBDayNight.isAfternoon?
    return :day
  end

  def self.current_time_display
    time = (defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now)
    hm = time.strftime("%H:%M") rescue "--:--"
    cat = current_time_category
    lbl = encounter_time_label(cat).upcase
    "#{hm}  #{lbl}"
  end

  def self.is_method_active_now?(time_cat)
    return true if time_cat == :any
    cur = current_time_category
    case time_cat
    when :night     then (cur == :night)
    when :morning   then (cur == :morning)
    when :evening   then (cur == :evening)
    when :afternoon then (cur == :afternoon || cur == :day)
    when :day       then (cur == :day || cur == :afternoon)
    else true
    end
  end

  # Restituisce l'elenco aggregato per specie di tutti i selvatici nella mappa
  def self.get_map_pokemon_list(map_id)
    version = ($PokemonGlobal && $PokemonGlobal.encounter_version) ? $PokemonGlobal.encounter_version : 0
    mode = get_encounter_mode
    enc_data = mode.get(map_id, version) if mode rescue nil
    enc_data = GameData::Encounter.get(map_id, version) if !enc_data rescue nil

    return [] if !enc_data || !enc_data.types || enc_data.types.empty?

    species_hash = {}
    species_order = []

    # Determina se la mappa distingue fasce orarie (Giorno/Notte/Mattina)
    has_time_split = enc_data.types.keys.any? { |t|
      cat = encounter_time_category(t)
      [:morning, :day, :afternoon, :evening, :night].include?(cat)
    }

    enc_data.types.each do |enc_type, slot_list|
      next if slot_list.nil? || slot_list.empty?

      time_cat = encounter_time_category(enc_type)
      time_lbl = encounter_time_label(time_cat)
      base_lbl = encounter_base_label(enc_type)
      act_now  = is_method_active_now?(time_cat)

      total_weight = 0
      slot_list.each { |s| total_weight += (s[0] || 1) if s }
      total_weight = 1 if total_weight <= 0

      type_species_weights = {}
      slot_list.each do |slot|
        next if !slot || !slot[1]
        sp = slot[1]
        w = slot[0] || 1
        min_l = slot[2] ? slot[2].to_i : 1
        max_l = slot[3] ? slot[3].to_i : min_l
        min_l, max_l = [min_l, max_l].min, [min_l, max_l].max

        type_species_weights[sp] ||= { :weight => 0, :min => min_l, :max => max_l }
        type_species_weights[sp][:weight] += w
        type_species_weights[sp][:min] = [type_species_weights[sp][:min], min_l].min
        type_species_weights[sp][:max] = [type_species_weights[sp][:max], max_l].max
      end

      type_species_weights.each do |sp, info|
        pct = (info[:weight] * 100.0 / total_weight).round
        pct = 1 if pct <= 0

        unless species_hash[sp]
          species_order << sp
          species_hash[sp] = {
            :species        => sp,
            :methods        => [],
            :min_level      => info[:min],
            :max_level      => info[:max],
            :max_chance     => pct,
            :has_time_split => has_time_split,
            :primary_label  => "#{base_lbl} (#{time_lbl})",
            :primary_base   => base_lbl,
            :primary_time   => time_lbl,
            :primary_icon   => "[#{base_lbl}]"
          }
        end

        cur = species_hash[sp]
        cur[:min_level] = [cur[:min_level], info[:min]].min
        cur[:max_level] = [cur[:max_level], info[:max]].max
        if pct > cur[:max_chance]
          cur[:max_chance]    = pct
          cur[:primary_label] = "#{base_lbl} (#{time_lbl})"
          cur[:primary_base]  = base_lbl
          cur[:primary_time]  = time_lbl
          cur[:primary_icon]  = "[#{base_lbl}]"
        end

        cur[:methods] << {
          :type          => enc_type,
          :base_label    => base_lbl,
          :time_category => time_cat,
          :time_label    => time_lbl,
          :chance        => pct,
          :min           => info[:min],
          :max           => info[:max],
          :active_now    => act_now
        }
      end
    end

    result = []
    species_order.each do |sp|
      item = species_hash[sp]
      sp_data = nil
      begin
        sp_data = GameData::Species.get(sp)
      rescue
        next
      end
      next if !sp_data

      item[:species_data] = sp_data
      item[:name]         = sp_data.name
      item[:id]           = sp_data.id

      item[:owned] = ($Trainer && $Trainer.pokedex) ? $Trainer.pokedex.owned?(sp) : false
      item[:seen]  = ($Trainer && $Trainer.pokedex) ? $Trainer.pokedex.seen?(sp) : false

      # Orari di comparsa
      item[:active_now] = item[:methods].any? { |m| m[:active_now] }

      if has_time_split
        has_any = item[:methods].any? { |m| m[:time_category] == :any }
        item[:has_day]     = has_any || item[:methods].any? { |m| [:day, :afternoon].include?(m[:time_category]) }
        item[:has_night]   = has_any || item[:methods].any? { |m| [:night, :evening].include?(m[:time_category]) }
        item[:has_morning] = has_any || item[:methods].any? { |m| m[:time_category] == :morning }
      else
        item[:has_day]     = true
        item[:has_night]   = true
        item[:has_morning] = true
      end

      has_only_night = item[:methods].all? { |m| [:night, :evening].include?(m[:time_category]) }
      has_only_day   = item[:methods].all? { |m| [:day, :afternoon].include?(m[:time_category]) }
      has_only_morn  = item[:methods].all? { |m| m[:time_category] == :morning }
      all_any        = item[:methods].all? { |m| m[:time_category] == :any }

      if has_only_night
        item[:time_tag] = "Solo Notte"
      elsif has_only_day
        item[:time_tag] = "Solo Giorno"
      elsif has_only_morn
        item[:time_tag] = "Solo Mattina"
      elsif all_any
        item[:time_tag] = "Sempre"
      else
        item[:time_tag] = "Giorno/Notte"
      end

      ch = item[:max_chance]
      if ch < 8
        item[:rarity_tag]   = "RARO"
        item[:rarity_color] = Color.new(230, 95, 255)
      elsif ch <= 20
        item[:rarity_tag]   = "NON COM."
        item[:rarity_color] = Color.new(70, 195, 255)
      else
        item[:rarity_tag]   = "COMUNE"
        item[:rarity_color] = Color.new(75, 235, 125)
      end

      stats = sp_data.base_stats rescue {}
      item[:hp]        = stats[:HP] || 0
      item[:attack]    = stats[:ATTACK] || 0
      item[:defense]   = stats[:DEFENSE] || 0
      item[:spatk]     = stats[:SPECIAL_ATTACK] || 0
      item[:spdef]     = stats[:SPECIAL_DEFENSE] || 0
      item[:speed]     = stats[:SPEED] || 0
      item[:bst_total] = item[:hp] + item[:attack] + item[:defense] + item[:spatk] + item[:spdef] + item[:speed]

      item[:type1] = sp_data.type1
      item[:type2] = (sp_data.type2 && sp_data.type2 != sp_data.type1) ? sp_data.type2 : nil

      result << item
    end

    result.sort_by! { |item| -item[:max_chance] }
    return result
  end

  # Calcola con cache in memoria (evita scansione ripetuta di 800 mappe!)
  def self.count_other_maps_for_species(species_id, current_map_id)
    key = "#{species_id}_#{current_map_id}"
    return @other_maps_cache[key] if @other_maps_cache.key?(key)

    count = 0
    mode = get_encounter_mode
    data_source = (mode && defined?(mode::DATA) && !mode::DATA.empty?) ? mode::DATA : GameData::Encounter::DATA rescue {}
    data_source.each_value do |enc|
      next if !enc || !enc.map || enc.map == current_map_id || !enc.types
      found = false
      enc.types.each_value do |slots|
        next if !slots
        if slots.any? { |s| s && s[1] == species_id }
          found = true
          break
        end
      end
      count += 1 if found
    end
    @other_maps_cache[key] = count
    return count
  end

  # Ricerca globale
  def self.search_species_everywhere(species_id)
    results = []
    mode = get_encounter_mode
    data_source = (mode && defined?(mode::DATA) && !mode::DATA.empty?) ? mode::DATA : GameData::Encounter::DATA rescue {}

    data_source.each_value do |enc|
      next if !enc || !enc.map || !enc.types
      map_id = enc.map
      map_max_chance = 0
      map_min_lvl = 999
      map_max_lvl = 1
      found_methods = []

      enc.types.each do |enc_type, slots|
        next if !slots || slots.empty?
        tot = 0
        slots.each { |s| tot += (s[0] || 1) if s }
        tot = 1 if tot <= 0

        sp_weight = 0
        slots.each do |s|
          next if !s || s[1] != species_id
          sp_weight += (s[0] || 1)
          min_l = s[2] ? s[2].to_i : 1
          max_l = s[3] ? s[3].to_i : min_l
          map_min_lvl = [map_min_lvl, min_l].min
          map_max_lvl = [map_max_lvl, max_l].max
        end

        if sp_weight > 0
          pct = (sp_weight * 100.0 / tot).round
          pct = 1 if pct <= 0
          map_max_chance = [map_max_chance, pct].max
          b_lbl = encounter_base_label(enc_type)
          t_lbl = encounter_time_label(encounter_time_category(enc_type))
          lbl_full = t_lbl == "Sempre" ? b_lbl : "#{b_lbl} (#{t_lbl})"
          found_methods << lbl_full
        end
      end

      if map_max_chance > 0
        results << {
          :map_id      => map_id,
          :map_name    => get_map_name(map_id),
          :chance      => map_max_chance,
          :min_level   => (map_min_lvl <= 100 ? map_min_lvl : 1),
          :max_level   => [map_max_lvl, 1].max,
          :methods_str => found_methods.uniq.join(", ")
        }
      end
    end

    results.sort_by! { |r| -r[:chance] }
    return results
  end
end

#===============================================================================
# Scene Grafica del Radar Habitat (Modern Dark Glass Edition - 512x384)
#===============================================================================
class PokemonHabitatRadar_Scene
  CARDS_PER_PAGE = 4

  FILTER_ALL     = 0
  FILTER_DAY     = 1
  FILTER_NIGHT   = 2
  FILTER_MORNING = 3
  FILTER_ACTIVE  = 4
  FILTER_NAMES   = ["TUTTI", "GIORNO", "NOTTE", "MATTINA", "ATTIVI ORA"]

  def pbStartScene(initial_map_id = nil)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}

    @map_id = initial_map_id || ($game_map ? $game_map.map_id : 1)
    @all_encounter_maps = HabitatRadarData.get_all_encounter_maps
    unless @all_encounter_maps.include?(@map_id)
      @all_encounter_maps.unshift(@map_id)
    end
    @map_index = @all_encounter_maps.index(@map_id) || 0

    @filter_mode = FILTER_ALL
    @pokemon_list = []
    @filtered_list = []
    @selected_index = 0
    @top_index = 0
    @current_battler_species = nil

    # Layer 0: Sfondo Dark Glass a tutto schermo (512x384) - Nessun bordo rosso residuo!
    @sprites["background"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["background"].z = 0
    draw_full_background(@sprites["background"].bitmap)

    # Layer 1: Pannelli geometrici scuri (z = 5)
    @sprites["panel_overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["panel_overlay"].z = 5

    # Bitmap precaricati in memoria RAM (zero accessi al disco a runtime!)
    @typebitmap = AnimatedBitmap.new("Graphics/Pictures/Pokedex/icon_types") rescue nil
    @pokeballOwn = AnimatedBitmap.new("Graphics/Pictures/Pokedex/icon_own") rescue nil

    # Layer 2: Battler grande
    @sprites["battler"] = PokemonSprite.new(@viewport)
    @sprites["battler"].setOffset(PictureOrigin::Center)
    @sprites["battler"].x = 326
    @sprites["battler"].y = 112
    @sprites["battler"].z = 10

    # Layer 2: 4 Mini icone
    CARDS_PER_PAGE.times do |i|
      @sprites["icon_#{i}"] = PokemonSpeciesIconSprite.new(nil, @viewport)
      @sprites["icon_#{i}"].setOffset(PictureOrigin::Center)
      @sprites["icon_#{i}"].z = 10
      @sprites["icon_#{i}"].visible = false
    end

    # Layer 3: Testi e indicatori (z = 20)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"].z = 20
    pbSetSystemFont(@sprites["overlay"].bitmap)

    load_current_map_data
    refresh_ui
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def draw_full_background(bitmap)
    w = Graphics.width
    h = Graphics.height
    for y in 0...h
      r = 11 + (4 * y / h)
      g = 15 + (7 * y / h)
      b = 25 + (11 * y / h)
      bitmap.fill_rect(0, y, w, 1, Color.new(r, g, b))
    end
    (0...h).step(24) do |gy|
      bitmap.fill_rect(0, gy, w, 1, Color.new(22, 30, 48, 110))
    end
  end

  def load_current_map_data
    @map_id = @all_encounter_maps[@map_index]
    @pokemon_list = HabitatRadarData.get_map_pokemon_list(@map_id)
    update_filtered_list
  end

  def update_filtered_list
    @filtered_list = []
    has_split = @pokemon_list.any? { |p| p[:has_time_split] }

    @pokemon_list.each do |p|
      matching_methods = []
      case @filter_mode
      when FILTER_DAY
        if has_split
          # Includi metodi specifici GIORNO + metodi "sempre" (:any)
          matching_methods = p[:methods].select { |m|
            [:day, :afternoon, :any].include?(m[:time_category])
          }
        else
          matching_methods = p[:methods]
        end
      when FILTER_NIGHT
        if has_split
          # Includi metodi specifici NOTTE + metodi "sempre" (:any)
          matching_methods = p[:methods].select { |m|
            [:night, :evening, :any].include?(m[:time_category])
          }
        else
          matching_methods = p[:methods]
        end
      when FILTER_MORNING
        if has_split
          # Includi metodi specifici MATTINA + metodi "sempre" (:any)
          matching_methods = p[:methods].select { |m|
            [:morning, :any].include?(m[:time_category])
          }
        else
          matching_methods = p[:methods]
        end
      when FILTER_ACTIVE
        matching_methods = p[:methods].select { |m| m[:active_now] }
      else
        # FILTER_ALL
        matching_methods = p[:methods]
      end

      next if matching_methods.empty?

      # Preferisci il metodo time-specifico per il display, se esiste
      time_specific = matching_methods.reject { |m| m[:time_category] == :any }
      best_source = time_specific.empty? ? matching_methods : time_specific
      best_m = best_source.max_by { |m| m[:chance] } || matching_methods[0]

      filtered_item = p.dup
      filtered_item[:display_chance] = best_m[:chance]
      filtered_item[:display_icon]   = "[#{best_m[:base_label]}]"
      filtered_item[:display_min]    = best_m[:min]
      filtered_item[:display_max]    = best_m[:max]
      filtered_item[:display_time]   = best_m[:time_label]

      ch = best_m[:chance]
      if ch < 8
        filtered_item[:rarity_tag]   = "RARO"
        filtered_item[:rarity_color] = Color.new(230, 95, 255)
      elsif ch <= 20
        filtered_item[:rarity_tag]   = "NON COM."
        filtered_item[:rarity_color] = Color.new(70, 195, 255)
      else
        filtered_item[:rarity_tag]   = "COMUNE"
        filtered_item[:rarity_color] = Color.new(75, 235, 125)
      end

      @filtered_list << filtered_item
    end

    @filtered_list.sort_by! { |p| -p[:display_chance] }
    @selected_index = 0
    @top_index = 0
    @current_battler_species = nil
  end

  def cycle_filter
    @filter_mode = (@filter_mode + 1) % FILTER_NAMES.length
    update_filtered_list
    pbSEPlay("GUI naming tab") rescue nil
    refresh_ui
  end

  def set_map(target_map_id)
    idx = @all_encounter_maps.index(target_map_id)
    if idx
      @map_index = idx
    else
      @all_encounter_maps.unshift(target_map_id)
      @map_index = 0
    end
    load_current_map_data
    refresh_ui
  end

  def next_map
    return if @all_encounter_maps.length <= 1
    @map_index = (@map_index + 1) % @all_encounter_maps.length
    load_current_map_data
    pbSEPlay("GUI naming tab") rescue nil
    refresh_ui
  end

  def prev_map
    return if @all_encounter_maps.length <= 1
    @map_index = (@map_index - 1 + @all_encounter_maps.length) % @all_encounter_maps.length
    load_current_map_data
    pbSEPlay("GUI naming tab") rescue nil
    refresh_ui
  end

  def cursor_down
    return if @filtered_list.empty?
    if @selected_index < @filtered_list.length - 1
      @selected_index += 1
      if @selected_index >= @top_index + CARDS_PER_PAGE
        @top_index += 1
      end
      pbSEPlay("GUI sel decision") rescue nil
      refresh_ui
    end
  end

  def cursor_up
    return if @filtered_list.empty?
    if @selected_index > 0
      @selected_index -= 1
      if @selected_index < @top_index
        @top_index -= 1
      end
      pbSEPlay("GUI sel decision") rescue nil
      refresh_ui
    end
  end

  def draw_panel(bitmap, x, y, w, h, bg_color, border_color = nil)
    bitmap.fill_rect(x, y, w, h, bg_color)
    if border_color
      bitmap.fill_rect(x, y, w, 1, border_color)
      bitmap.fill_rect(x, y + h - 1, w, 1, border_color)
      bitmap.fill_rect(x, y, 1, h, border_color)
      bitmap.fill_rect(x + w - 1, y, 1, h, border_color)
    end
  end

  def refresh_ui
    panel = @sprites["panel_overlay"].bitmap
    panel.clear

    overlay = @sprites["overlay"].bitmap
    overlay.clear

    # Il radar lavora sulla risoluzione logica di 512x384. Con il font Power
    # Green a 20px le etichette delle tab e le righe ravvicinate dei pannelli
    # si sovrappongono quando la schermata viene ingrandita. 16px mantiene il
    # look pixel-art, ma lascia margini reali fra testo, bordi e righe.
    overlay.font.size = 16

    textpos = []

    c_white   = Color.new(245, 248, 255)
    c_shadow  = Color.new(10, 14, 20)
    c_cyan    = Color.new(65, 215, 255)
    c_gold    = Color.new(255, 215, 50)
    c_silver  = Color.new(150, 165, 185)
    c_red     = Color.new(255, 85, 85)
    c_green   = Color.new(75, 235, 125)

    # =====================================================================
    # 1. HEADER (y=0..30)
    # =====================================================================
    draw_panel(panel, 0, 0, 512, 30, Color.new(12, 17, 28), Color.new(35, 52, 78))
    panel.fill_rect(0, 30, 512, 1, Color.new(0, 215, 255))

    map_name = HabitatRadarData.get_map_name(@map_id)
    display_name = map_name.length > 13 ? "#{map_name[0...11]}.." : map_name
    map_num = "(#{@map_index + 1}/#{@all_encounter_maps.length})"
    textpos << ["< #{display_name} >  #{map_num}", 10, 6, 0, c_white, c_shadow]

    # Orario in-game & Fascia (centrato esattamente a x=256)
    draw_panel(panel, 186, 4, 140, 22, Color.new(24, 34, 18), Color.new(200, 180, 40))
    time_str = HabitatRadarData.current_time_display
    textpos << [time_str, 256, 6, 2, c_gold, c_shadow]

    # Rapporto Pokédex (allineato a destra)
    total_sp = @pokemon_list.length
    caught_sp = @pokemon_list.count { |p| p[:owned] }
    if total_sp > 0
      pct = (caught_sp * 100.0 / total_sp).round
      pct_col = (caught_sp >= total_sp) ? c_gold : c_cyan
      textpos << ["Catturati: #{caught_sp}/#{total_sp} (#{pct}%)", 502, 6, 1, pct_col, c_shadow]
    end

    # =====================================================================
    # 2. TAB FILTRI ORARI (y=32..54) - 5 Tab simmetriche da 96px (8..504)
    # =====================================================================
    tab_defs = [
      ["TUTTI",       8,  96],
      ["GIORNO",    108,  96],
      ["NOTTE",     208,  96],
      ["MATTINA",   308,  96],
      ["ATTIVI ORA", 408,  96]
    ]

    tab_defs.each_with_index do |t_info, i|
      t_name, tx, tw = t_info
      is_cur_tab = (i == @filter_mode)
      if is_cur_tab
        draw_panel(panel, tx, 32, tw, 22, Color.new(0, 130, 205), Color.new(0, 225, 255))
        textpos << [t_name, tx + (tw / 2), 29, 2, c_white, c_shadow]
      else
        draw_panel(panel, tx, 32, tw, 22, Color.new(16, 22, 34), Color.new(35, 48, 70))
        textpos << [t_name, tx + (tw / 2), 29, 2, c_silver, c_shadow]
      end
    end

    # =====================================================================
    # 3. LISTA POKEMON ALLARGATA (x=8, y=56, w=270, h=294)
    # =====================================================================
    draw_panel(panel, 8, 56, 270, 294, Color.new(13, 17, 27), Color.new(35, 48, 72))

    CARDS_PER_PAGE.times { |i| @sprites["icon_#{i}"].visible = false }

    f_count = @filtered_list.length
    draw_panel(panel, 8, 56, 270, 24, Color.new(18, 24, 38), Color.new(35, 50, 75))
    textpos << ["RADAR SELVATICI (#{f_count})", 14, 55, 0, c_cyan, c_shadow]

    if @filtered_list.empty?
      textpos << ["Nessun selvatico", 143, 140, 2, c_silver, c_shadow]
      textpos << ["in questa fascia oraria.", 143, 160, 2, c_silver, c_shadow]
      textpos << ["Premi [Z] per cambiare filtro", 143, 190, 2, c_cyan, c_shadow]
    else
      if @top_index > 0
        textpos << ["^", 268, 55, 1, c_cyan, c_shadow]
      end

      CARDS_PER_PAGE.times do |slot_i|
        item_i = @top_index + slot_i
        break if item_i >= @filtered_list.length

        item = @filtered_list[item_i]
        card_x = 12
        card_y = 82 + (slot_i * 62)
        card_w = 262
        card_h = 58
        is_sel = (item_i == @selected_index)

        if is_sel
          draw_panel(panel, card_x, card_y, card_w, card_h, Color.new(24, 44, 72), Color.new(0, 220, 255))
          panel.fill_rect(card_x, card_y, 3, card_h, Color.new(0, 220, 255))
        else
          draw_panel(panel, card_x, card_y, card_w, card_h, Color.new(18, 24, 38), Color.new(35, 48, 68))
        end

        # Icona Pokémon (centrata a x=card_x + 26, y=card_y + 29)
        icon_sprite = @sprites["icon_#{slot_i}"]
        if icon_sprite
          if icon_sprite.species != item[:species]
            icon_sprite.species = item[:species]
          end
          icon_sprite.x = card_x + 26
          icon_sprite.y = card_y + 29
          icon_sprite.visible = true
          icon_sprite.color = item[:seen] ? Color.new(0, 0, 0, 0) : Color.new(0, 0, 0, 240)
        end

        # Pokeball cattura (a sinistra del nome)
        name_x = card_x + 52
        if item[:owned] && @pokeballOwn && @pokeballOwn.bitmap
          overlay.stretch_blt(Rect.new(name_x, card_y + 8, 14, 14), @pokeballOwn.bitmap, Rect.new(0, 0, @pokeballOwn.width, @pokeballOwn.height))
          name_x += 16
        end

        # Linea 1: Nome + Rarita/Chance a destra
        raw_name = item[:seen] ? item[:name] : "?????????"
        p_name = raw_name.length > 10 ? "#{raw_name[0...9]}." : raw_name
        p_col = is_sel ? c_white : Color.new(225, 232, 245)
        textpos << [p_name, name_x, card_y + 6, 0, p_col, c_shadow]

        display_ch = item[:display_chance] || item[:max_chance]
        textpos << ["#{display_ch}% #{item[:rarity_tag]}", card_x + card_w - 8, card_y + 6, 1, item[:rarity_color], c_shadow]

        # Linea 2: Metodo & Livello a sinistra, Stato orario a destra
        min_l = item[:display_min] || item[:min_level] || 1
        max_l = item[:display_max] || item[:max_level] || min_l
        lvl = (min_l == max_l) ? "L.#{min_l}" : "L.#{min_l}-#{max_l}"
        meth_icon = item[:display_icon] || item[:primary_icon] || ""
        textpos << ["#{meth_icon} #{lvl}", card_x + 52, card_y + 32, 0, Color.new(160, 175, 195), c_shadow]

        # Tag orario / GPS a destra sulla stessa Linea 2
        if $PokemonGlobal && $PokemonGlobal.radar_tracked_species == item[:id]
          textpos << ["[GPS]", card_x + card_w - 8, card_y + 32, 1, c_gold, c_shadow]
        elsif item[:active_now]
          panel.fill_rect(card_x + card_w - 60, card_y + 39, 5, 5, c_green)
          textpos << ["ATTIVO", card_x + card_w - 8, card_y + 32, 1, c_green, c_shadow]
        else
          textpos << [item[:time_tag], card_x + card_w - 8, card_y + 32, 1, Color.new(140, 160, 190), c_shadow]
        end
      end

      # Indicatore v Altro (centrato a x=143)
      if @top_index + CARDS_PER_PAGE < @filtered_list.length
        rem = f_count - @top_index - CARDS_PER_PAGE
        textpos << ["v Altri #{rem} Pokemon", 143, 326, 2, c_cyan, c_shadow]
      end
    end

    # =====================================================================
    # 4. PANNELLO DETTAGLIO (x=284, y=56, w=220, h=140)
    # =====================================================================
    draw_panel(panel, 284, 56, 220, 140, Color.new(16, 22, 34), Color.new(45, 65, 95))

    cur = (@filtered_list.empty? || @selected_index >= @filtered_list.length) ? nil : @filtered_list[@selected_index]

    if cur
      is_seen = cur[:seen]
      sp_data = cur[:species_data]

      # Header card dettaglio (y = 56..82)
      draw_panel(panel, 284, 56, 220, 26, Color.new(20, 28, 44), Color.new(40, 60, 90))
      dex_num = sprintf("#%03d", (sp_data.id_number rescue 0))
      name_str = is_seen ? cur[:name] : "?????????"
      textpos << ["#{dex_num} #{name_str}", 290, 57, 0, c_white, c_shadow]
      textpos << [cur[:rarity_tag], 498, 57, 1, cur[:rarity_color], c_shadow]

      # Battler sprite (centrato nella colonna sinistra: x=326, y=112, max_dim=50)
      if @current_battler_species != cur[:species]
        @current_battler_species = cur[:species]
        @sprites["battler"].visible = true
        @sprites["battler"].setPokemonBitmapSpecies(cur[:species]) rescue nil
        if @sprites["battler"].bitmap
          max_dim = [@sprites["battler"].bitmap.width, @sprites["battler"].bitmap.height].max
          if max_dim > 50
            scale = 50.0 / max_dim
            @sprites["battler"].zoom_x = scale
            @sprites["battler"].zoom_y = scale
          else
            @sprites["battler"].zoom_x = 1.0
            @sprites["battler"].zoom_y = 1.0
          end
        end
      end
      @sprites["battler"].x = 326
      @sprites["battler"].y = 112
      @sprites["battler"].color = is_seen ? Color.new(0, 0, 0, 0) : Color.new(0, 0, 0, 255)

      # Piedistallo centrato a x=326
      panel.fill_rect(302, 136, 48, 4, Color.new(28, 45, 75))

      # Tipi centrati a x=326 (y = 144..182)
      if is_seen && @typebitmap && @typebitmap.bitmap
        type1 = cur[:type1]
        type2 = cur[:type2]
        t1_num = type1 ? (GameData::Type.get(type1).id_number rescue 0) : nil
        t2_num = type2 ? (GameData::Type.get(type2).id_number rescue 0) : nil
        if t1_num && t2_num
          overlay.stretch_blt(Rect.new(298, 144, 56, 17), @typebitmap.bitmap, Rect.new(0, t1_num * 32, 96, 32))
          overlay.stretch_blt(Rect.new(298, 164, 56, 17), @typebitmap.bitmap, Rect.new(0, t2_num * 32, 96, 32))
        elsif t1_num
          overlay.stretch_blt(Rect.new(298, 152, 56, 19), @typebitmap.bitmap, Rect.new(0, t1_num * 32, 96, 32))
        end
      elsif !is_seen
        textpos << ["Tipo: ???", 326, 154, 2, c_silver, c_shadow]
      end

      # Sub-colonna destra: Box Disponibilità (y = 86..108, w = 136)
      if cur[:active_now]
        draw_panel(panel, 362, 86, 136, 22, Color.new(18, 52, 32), Color.new(60, 220, 100))
        textpos << ["DISPONIBILE ORA", 430, 82, 2, c_green, c_shadow]
      else
        draw_panel(panel, 362, 86, 136, 22, Color.new(42, 28, 32), Color.new(180, 70, 70))
        textpos << [cur[:time_tag].upcase, 430, 82, 2, Color.new(240, 160, 160), c_shadow]
      end

      # Righe Dettaglio Incontro isolate verticalmente (y = 112, 132, 152, 170)
      m_list = cur[:methods] || []
      if m_list.length > 0
        m1 = m_list[0]
        textpos << ["#{m1[:base_label]} (#{m1[:chance]}%)", 368, 112, 0, Color.new(235, 240, 255), c_shadow]
        lvl_str = (cur[:min_level] == cur[:max_level]) ? "Livello #{cur[:min_level]}" : "Livelli: #{cur[:min_level]} - #{cur[:max_level]}"
        textpos << [lvl_str, 368, 132, 0, Color.new(160, 180, 210), c_shadow]
        textpos << ["Orario: #{m1[:time_label]}", 368, 152, 0, Color.new(160, 185, 220), c_shadow]
      end
      if m_list.length > 1
        m2 = m_list[1]
        textpos << ["+ #{m2[:base_label]} (#{m2[:chance]}%)", 368, 170, 0, Color.new(140, 165, 195), c_shadow]
      else
        textpos << ["Unico metodo", 368, 170, 0, Color.new(110, 130, 155), c_shadow]
      end

      # ===================================================================
      # 5. PANNELLO STATISTICHE BASE & GPS (x=284, y=198, w=220, h=152)
      # ===================================================================
      draw_panel(panel, 284, 198, 220, 152, Color.new(16, 22, 34), Color.new(45, 65, 95))

      if is_seen
        textpos << ["STATISTICHE BASE", 290, 202, 0, c_cyan, c_shadow]
        textpos << ["BST #{cur[:bst_total]}", 498, 202, 1, c_gold, c_shadow]

        stats = [
          [:hp,      "HP",  Color.new(75, 220, 115)],
          [:attack,  "Atk", Color.new(250, 140, 50)],
          [:defense, "Def", Color.new(245, 205, 55)],
          [:spatk,   "SpA", Color.new(55, 200, 250)],
          [:spdef,   "SpD", Color.new(95, 130, 250)],
          [:speed,   "Spe", Color.new(250, 90, 165)]
        ]

        stats.each_with_index do |st, idx|
          col = idx / 3
          row = idx % 3
          bx = (col == 0) ? 290 : 395
          by = 224 + (row * 19)
          val = cur[st[0]] || 0

          textpos << [st[1], bx, by, 0, Color.new(160, 175, 195), c_shadow]
          textpos << ["#{val}", bx + 26, by, 0, Color.new(245, 248, 255), c_shadow]

          bar_max = 34
          bar_fill = (val * bar_max / 140.0).round.clamp(2, bar_max)
          panel.fill_rect(bx + 54, by + 5, bar_max, 6, Color.new(28, 36, 50))
          overlay.fill_rect(bx + 54, by + 5, bar_fill, 6, st[2])
        end
      else
        textpos << ["STATISTICHE BASE", 290, 202, 0, c_cyan, c_shadow]
        textpos << ["Cattura per svelare", 394, 230, 2, c_silver, c_shadow]
        textpos << ["le statistiche!", 394, 250, 2, c_silver, c_shadow]
      end

      # Linea di separazione info GPS
      panel.fill_rect(288, 286, 212, 1, Color.new(35, 48, 70))

      # Altre mappe
      other = HabitatRadarData.count_other_maps_for_species(cur[:id], @map_id)
      if other == 0
        textpos << ["Esclusivo di quest'area!", 290, 290, 0, c_gold, c_shadow]
      else
        textpos << ["Presente in altre #{other} mappe", 290, 290, 0, c_cyan, c_shadow]
      end

      # Prompt GPS
      is_target = ($PokemonGlobal && $PokemonGlobal.radar_tracked_species == cur[:id])
      gps_text = is_target ? "C: Rimuovi Target GPS" : "C: Imposta come Target GPS"
      gps_col = is_target ? c_red : c_green
      textpos << [gps_text, 290, 310, 0, gps_col, c_shadow]

      # Stato GPS globale
      if $PokemonGlobal && $PokemonGlobal.radar_tracked_species
        t_name = "?"
        begin; t_name = GameData::Species.get($PokemonGlobal.radar_tracked_species).name; rescue; end
        textpos << ["GPS: #{t_name}", 290, 324, 0, c_gold, c_shadow]
      else
        textpos << ["GPS: Nessun bersaglio", 290, 324, 0, Color.new(140, 155, 175), c_shadow]
      end

    else
      @sprites["battler"].visible = false
      @current_battler_species = nil
      textpos << ["Nessun dettaglio", 394, 80, 2, c_silver, c_shadow]
      draw_panel(panel, 284, 198, 220, 152, Color.new(16, 22, 34), Color.new(45, 65, 95))
      textpos << ["Seleziona un percorso", 394, 260, 2, c_silver, c_shadow]
    end

    # =====================================================================
    # 6. FOOTER TOOLBAR (y=354..384, h=30) - 5 Sezioni Centrate
    # =====================================================================
    draw_panel(panel, 0, 354, 512, 30, Color.new(12, 16, 26), Color.new(35, 50, 75))
    panel.fill_rect(0, 354, 512, 1, Color.new(0, 210, 255))

    textpos << ["< > Mappe",   56, 358, 2, c_white,  c_shadow]
    textpos << ["^ v Lista",  154, 358, 2, c_white,  c_shadow]
    textpos << ["[Z] Filtri", 256, 358, 2, c_cyan,   c_shadow]
    textpos << ["[C] GPS",    358, 358, 2, c_green,  c_shadow]
    textpos << ["[X] Esci",   456, 358, 2, c_silver, c_shadow]

    pbDrawTextPositions(overlay, textpos)
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @typebitmap.dispose if @typebitmap rescue nil
    @pokeballOwn.dispose if @pokeballOwn rescue nil
    @viewport.dispose
  end
end

#===============================================================================
# Screen Controller per il Radar Habitat (Zero-Lag Responsive Controls)
#===============================================================================
class PokemonHabitatRadarScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(initial_map_id = nil)
    @scene.pbStartScene(initial_map_id)
    loop do
      Graphics.update
      Input.update
      @scene.pbUpdate

      # Reattivita istantanea con supporto repeat (tieni premuto per scorrere fluido!)
      if Input.trigger?(Input::LEFT) || Input.repeat?(Input::LEFT)
        @scene.prev_map
      elsif Input.trigger?(Input::RIGHT) || Input.repeat?(Input::RIGHT)
        @scene.next_map
      elsif Input.trigger?(Input::UP) || Input.repeat?(Input::UP)
        @scene.cursor_up
      elsif Input.trigger?(Input::DOWN) || Input.repeat?(Input::DOWN)
        @scene.cursor_down
      elsif Input.trigger?(Input::JUMPUP)
        4.times { @scene.cursor_up }
      elsif Input.trigger?(Input::JUMPDOWN)
        4.times { @scene.cursor_down }
      elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::SPECIAL)
        @scene.cycle_filter
      elsif Input.trigger?(Input::USE)
        pbHandleActionChoice
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      end
    end
    @scene.pbEndScene
  end

  # Gestione menu contestuale su card selezionata
  def pbHandleActionChoice
    list = @scene.instance_variable_get(:@filtered_list)
    sel = @scene.instance_variable_get(:@selected_index)

    choices = []
    cmd_track   = -1
    cmd_routes  = -1
    cmd_filter  = -1
    cmd_search  = -1
    cmd_cancel  = -1

    cur_item = (list && sel && sel < list.length) ? list[sel] : nil

    if cur_item
      p_name = cur_item[:seen] ? cur_item[:name] : "Pokemon sconosciuto"
      is_tracked = ($PokemonGlobal && $PokemonGlobal.radar_tracked_species == cur_item[:id])

      if is_tracked
        choices[cmd_track = choices.length] = _INTL("Disattiva Target GPS ({1})", p_name)
      else
        choices[cmd_track = choices.length] = _INTL("Imposta come Target GPS ({1})", p_name)
      end

      choices[cmd_routes = choices.length] = _INTL("Mostra tutti i percorsi di {1}", p_name)
    end

    choices[cmd_filter = choices.length] = _INTL("Cambia Filtro Orario (Giorno/Notte)")
    choices[cmd_search = choices.length] = _INTL("Ricerca Globale Pokemon per Nome")
    choices[cmd_cancel = choices.length] = _INTL("Annulla")

    choice = pbShowCommands(nil, choices, -1)

    if choice == cmd_track && cur_item
      if $PokemonGlobal.radar_tracked_species == cur_item[:id]
        $PokemonGlobal.radar_tracked_species = nil
        pbSEPlay("GUI menu close") rescue nil
        pbMessage(_INTL("Tracciamento del bersaglio disattivato."))
      else
        $PokemonGlobal.radar_tracked_species = cur_item[:id]
        pbSEPlay("itemlevel") rescue nil
        pbMessage(_INTL("{1} impostato come Target!\nRiceverai un allarme quando apparira in battaglia!", cur_item[:name]))
      end
      @scene.refresh_ui

    elsif choice == cmd_routes && cur_item
      pbShowAllRoutesForSpecies(cur_item[:id], cur_item[:name])

    elsif choice == cmd_filter
      @scene.cycle_filter

    elsif choice == cmd_search
      pbOpenSearchPrompt
    end
  end

  # Mostra tutte le mappe in cui compare una specie specifica ordinate per %
  def pbShowAllRoutesForSpecies(species_id, species_name)
    results = HabitatRadarData.search_species_everywhere(species_id)
    if results.empty?
      pbMessage(_INTL("{1} non compare in alcuna mappa selvatica nel salvataggio attuale.", species_name))
      return
    end

    loop do
      commands = []
      results.each_with_index do |r, i|
        commands << sprintf("%d. %s - %d%% (Lv.%d-%d) [%s]", i + 1, r[:map_name], r[:chance], r[:min_level], r[:max_level], r[:methods_str])
      end
      commands << _INTL("Imposta {1} come Target GPS", species_name)
      commands << _INTL("Torna indietro")

      choice = pbShowCommands(nil, commands, -1)
      if choice < 0 || choice == commands.length - 1
        break
      elsif choice == commands.length - 2
        $PokemonGlobal.radar_tracked_species = species_id
        pbSEPlay("itemlevel") rescue nil
        pbMessage(_INTL("{1} impostato come Target GPS!", species_name))
        @scene.refresh_ui
        break
      else
        target_map = results[choice][:map_id]
        @scene.set_map(target_map)
        pbSEPlay("GUI naming tab") rescue nil
        break
      end
    end
  end

  # Prompt di Ricerca Globale libera per nome
  def pbOpenSearchPrompt
    query = pbMessageFreeText(_INTL("Nome del Pokemon da cercare:"), "", false, 24)
    return if query.nil? || query.strip.empty?
    query = query.strip.downcase

    matches = []
    GameData::Species.each do |sp|
      if sp.name.downcase.include?(query) || sp.id.to_s.downcase.include?(query)
        matches << sp
      end
    end

    if matches.empty?
      pbMessage(_INTL("Nessun Pokemon trovato con '{1}'.", query))
      return
    end

    chosen_species = nil
    if matches.length == 1
      chosen_species = matches[0]
    else
      choices = matches[0...30].map { |sp| sp.name }
      choice = pbShowCommands(nil, choices, -1)
      return if choice < 0
      chosen_species = matches[choice]
    end

    return if !chosen_species
    pbShowAllRoutesForSpecies(chosen_species.id, chosen_species.name)
  end
end
