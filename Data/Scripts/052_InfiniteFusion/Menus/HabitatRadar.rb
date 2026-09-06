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

  def self.encounter_type_label(type)
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

  def self.encounter_type_symbol(type)
    t = type.to_s
    case
    when t.start_with?("Land")      then "[Erba]"
    when t.start_with?("Water")     then "[Surf]"
    when t.include?("Rod")          then "[Pesca]"
    when t.start_with?("Cave")      then "[Grotta]"
    when t == "RockSmash"           then "[Roccia]"
    when t.start_with?("Headbutt")  then "[Albero]"
    else "[Selvatico]"
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

    enc_data.types.each do |enc_type, slot_list|
      next if slot_list.nil? || slot_list.empty?

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
            :species       => sp,
            :methods       => [],
            :min_level     => info[:min],
            :max_level     => info[:max],
            :max_chance    => pct,
            :primary_label => encounter_type_label(enc_type),
            :primary_icon  => encounter_type_symbol(enc_type)
          }
        end

        cur = species_hash[sp]
        cur[:min_level] = [cur[:min_level], info[:min]].min
        cur[:max_level] = [cur[:max_level], info[:max]].max
        if pct > cur[:max_chance]
          cur[:max_chance] = pct
          cur[:primary_label] = encounter_type_label(enc_type)
          cur[:primary_icon]  = encounter_type_symbol(enc_type)
        end
        cur[:methods] << {
          :type   => enc_type,
          :label  => encounter_type_label(enc_type),
          :chance => pct,
          :min    => info[:min],
          :max    => info[:max]
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

      ch = item[:max_chance]
      if ch < 8
        item[:rarity_tag]   = "RARO"
        item[:rarity_color] = Color.new(225, 90, 245)
      elsif ch <= 20
        item[:rarity_tag]   = "NON COMUNE"
        item[:rarity_color] = Color.new(70, 190, 255)
      else
        item[:rarity_tag]   = "COMUNE"
        item[:rarity_color] = Color.new(85, 235, 125)
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
          found_methods << encounter_type_label(enc_type)
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
# Scene Grafica del Radar Habitat (Next-Level Elegance & Zero Lag)
#===============================================================================
class PokemonHabitatRadar_Scene
  CARDS_PER_PAGE = 4

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

    @pokemon_list = []
    @selected_index = 0
    @top_index = 0
    @current_battler_species = nil

    # Layer 0: Sfondo
    addBackgroundPlane(@sprites, "background", "Pokedex/bg_area", @viewport)
    if !@sprites["background"] || !@sprites["background"].bitmap
      addBackgroundPlane(@sprites, "background", "Pokedex/bg_list", @viewport)
    end
    @sprites["background"].z = 0 if @sprites["background"]

    # Layer 1: Pannelli geometrici scuri (z = 5)
    @sprites["panel_overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["panel_overlay"].z = 5

    # Bitmap precaricati in memoria RAM (zero accessi al disco a runtime!)
    @typebitmap = AnimatedBitmap.new("Graphics/Pictures/Pokedex/icon_types") rescue nil
    @pokeballOwn = AnimatedBitmap.new("Graphics/Pictures/Pokedex/icon_own") rescue nil

    # Layer 2: Battler grande
    @sprites["battler"] = PokemonSprite.new(@viewport)
    @sprites["battler"].setOffset(PictureOrigin::Center)
    @sprites["battler"].x = 380
    @sprites["battler"].y = 82
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

  def load_current_map_data
    @map_id = @all_encounter_maps[@map_index]
    @pokemon_list = HabitatRadarData.get_map_pokemon_list(@map_id)
    @selected_index = 0
    @top_index = 0
    @current_battler_species = nil
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
    return if @pokemon_list.empty?
    if @selected_index < @pokemon_list.length - 1
      @selected_index += 1
      if @selected_index >= @top_index + CARDS_PER_PAGE
        @top_index += 1
      end
      pbSEPlay("GUI sel decision") rescue nil
      refresh_ui
    end
  end

  def cursor_up
    return if @pokemon_list.empty?
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

    # FONT COMPATTO: size 20 invece del default 29 per evitare sovrapposizioni
    overlay.font.size = 20

    textpos = []

    c_white   = Color.new(245, 248, 255)
    c_shadow  = Color.new(10, 14, 20)
    c_cyan    = Color.new(65, 215, 255)
    c_gold    = Color.new(255, 210, 45)
    c_silver  = Color.new(165, 175, 195)
    c_red     = Color.new(255, 85, 85)
    c_green   = Color.new(80, 230, 120)

    # =====================================================================
    # 1. HEADER (y=2, h=24)
    # =====================================================================
    draw_panel(panel, 4, 2, 504, 24, Color.new(16, 22, 34), Color.new(55, 80, 115))

    map_name = HabitatRadarData.get_map_name(@map_id)
    display_name = map_name.length > 14 ? "#{map_name[0...12]}.." : map_name
    map_num = "#{@map_index + 1}/#{@all_encounter_maps.length}"
    textpos << ["<< #{display_name} >> #{map_num}", 10, 4, 0, c_white, c_shadow]

    total_sp = @pokemon_list.length
    caught_sp = @pokemon_list.count { |p| p[:owned] }
    if total_sp > 0
      pct = (caught_sp * 100.0 / total_sp).round
      if caught_sp >= total_sp
        textpos << ["100%!", 502, 4, 1, c_gold, c_shadow]
      else
        textpos << ["#{caught_sp}/#{total_sp} #{pct}%", 502, 4, 1, c_cyan, c_shadow]
      end
    end

    # =====================================================================
    # 2. LISTA POKEMON (x=4, y=28, w=240, h=292)
    # =====================================================================
    draw_panel(panel, 4, 28, 240, 292, Color.new(14, 18, 28), Color.new(45, 65, 95))

    CARDS_PER_PAGE.times { |i| @sprites["icon_#{i}"].visible = false }

    if @pokemon_list.empty?
      textpos << ["Nessun Pokemon", 124, 110, 2, c_silver, c_shadow]
      textpos << ["in questa zona.", 124, 132, 2, c_silver, c_shadow]
      textpos << ["Usa << / >> per", 124, 168, 2, c_cyan, c_shadow]
      textpos << ["sfogliare le mappe.", 124, 190, 2, c_cyan, c_shadow]
    else
      if @top_index > 0
        textpos << ["^", 124, 30, 2, c_cyan, c_shadow]
      end
      if @top_index + CARDS_PER_PAGE < @pokemon_list.length
        textpos << ["v Altro", 124, 298, 2, c_cyan, c_shadow]
      end

      CARDS_PER_PAGE.times do |slot_i|
        item_i = @top_index + slot_i
        break if item_i >= @pokemon_list.length

        item = @pokemon_list[item_i]
        card_x = 8
        card_y = 44 + (slot_i * 62)
        card_w = 232
        card_h = 56
        is_sel = (item_i == @selected_index)

        if is_sel
          draw_panel(panel, card_x, card_y, card_w, card_h, Color.new(28, 48, 76), Color.new(0, 220, 255))
          panel.fill_rect(card_x, card_y, 3, card_h, Color.new(0, 220, 255))
        else
          draw_panel(panel, card_x, card_y, card_w, card_h, Color.new(20, 26, 40), Color.new(45, 58, 80))
        end

        # Pokeball icona cattura
        if item[:owned] && @pokeballOwn && @pokeballOwn.bitmap
          overlay.blt(card_x + 4, card_y + 14, @pokeballOwn.bitmap, Rect.new(0, 0, @pokeballOwn.width, @pokeballOwn.height))
        end

        # Icona Pokemon
        icon_sprite = @sprites["icon_#{slot_i}"]
        if icon_sprite
          if icon_sprite.species != item[:species]
            icon_sprite.species = item[:species]
          end
          icon_sprite.x = card_x + 40
          icon_sprite.y = card_y + 28
          icon_sprite.visible = true
          icon_sprite.color = item[:seen] ? Color.new(0, 0, 0, 0) : Color.new(0, 0, 0, 240)
        end

        # Nome
        p_name = item[:seen] ? item[:name] : "?????????"
        p_col = is_sel ? c_white : Color.new(225, 230, 240)
        textpos << [p_name, card_x + 68, card_y + 6, 0, p_col, c_shadow]

        # Target GPS
        if $PokemonGlobal && $PokemonGlobal.radar_tracked_species == item[:id]
          textpos << ["GPS", card_x + card_w - 6, card_y + 6, 1, c_gold, c_shadow]
        end

        # Livello e metodo
        lvl = (item[:min_level] == item[:max_level]) ? "Lv#{item[:min_level]}" : "Lv#{item[:min_level]}-#{item[:max_level]}"
        textpos << ["#{item[:primary_icon]} #{lvl}", card_x + 68, card_y + 28, 0, c_silver, c_shadow]

        # Percentuale
        textpos << ["#{item[:max_chance]}%", card_x + card_w - 6, card_y + 28, 1, item[:rarity_color], c_shadow]
      end
    end

    # =====================================================================
    # 3. PANNELLO DETTAGLIO (x=248, y=28, w=260, h=124)
    # =====================================================================
    draw_panel(panel, 248, 28, 260, 124, Color.new(18, 24, 38), Color.new(50, 75, 110))

    cur = (@pokemon_list.empty? || @selected_index >= @pokemon_list.length) ? nil : @pokemon_list[@selected_index]

    if cur
      is_seen = cur[:seen]
      sp_data = cur[:species_data]

      # Battler sprite (carica solo se specie cambiata)
      if @current_battler_species != cur[:species]
        @current_battler_species = cur[:species]
        @sprites["battler"].visible = true
        @sprites["battler"].setPokemonBitmapSpecies(cur[:species]) rescue nil
        if @sprites["battler"].bitmap
          max_dim = [@sprites["battler"].bitmap.width, @sprites["battler"].bitmap.height].max
          if max_dim > 64
            scale = 64.0 / max_dim
            @sprites["battler"].zoom_x = scale
            @sprites["battler"].zoom_y = scale
          else
            @sprites["battler"].zoom_x = 1.0
            @sprites["battler"].zoom_y = 1.0
          end
        end
      end
      @sprites["battler"].color = is_seen ? Color.new(0, 0, 0, 0) : Color.new(0, 0, 0, 255)

      # Nome e numero dex
      dex_num = sprintf("#%03d", (sp_data.id_number rescue 0))
      name_str = is_seen ? cur[:name] : "?????????"
      textpos << ["#{dex_num} #{name_str}", 254, 32, 0, c_white, c_shadow]
      textpos << [cur[:rarity_tag], 504, 32, 1, cur[:rarity_color], c_shadow]

      # Tipi (sotto il battler)
      if is_seen && @typebitmap && @typebitmap.bitmap
        type1 = cur[:type1]
        type2 = cur[:type2]
        t1_num = type1 ? (GameData::Type.get(type1).id_number rescue 0) : nil
        t2_num = type2 ? (GameData::Type.get(type2).id_number rescue 0) : nil
        if t1_num && t2_num
          overlay.blt(264, 118, @typebitmap.bitmap, Rect.new(0, t1_num * 32, 96, 32))
          overlay.blt(374, 118, @typebitmap.bitmap, Rect.new(0, t2_num * 32, 96, 32))
        elsif t1_num
          overlay.blt(320, 118, @typebitmap.bitmap, Rect.new(0, t1_num * 32, 96, 32))
        end
      elsif !is_seen
        textpos << ["Tipo: ???", 378, 128, 2, c_silver, c_shadow]
      end

      # ===================================================================
      # 4. PANNELLO STATISTICHE (x=248, y=156, w=260, h=164)
      # ===================================================================
      draw_panel(panel, 248, 156, 260, 164, Color.new(18, 24, 38), Color.new(50, 75, 110))

      if is_seen
        textpos << ["STAT BASE", 254, 160, 0, c_cyan, c_shadow]
        textpos << ["BST #{cur[:bst_total]}", 504, 160, 1, c_gold, c_shadow]

        stats = [
          [:hp,      "HP ", Color.new(70, 215, 110)],
          [:attack,  "Atk", Color.new(250, 135, 50)],
          [:defense, "Def", Color.new(245, 205, 55)],
          [:spatk,   "SpA", Color.new(50, 195, 250)],
          [:spdef,   "SpD", Color.new(95, 125, 250)],
          [:speed,   "Spe", Color.new(250, 85, 165)]
        ]

        stats.each_with_index do |st, idx|
          col = idx / 3
          row = idx % 3
          bx = 254 + (col * 130)
          by = 184 + (row * 22)
          val = cur[st[0]] || 0

          textpos << [st[1], bx, by, 0, c_silver, c_shadow]
          textpos << ["#{val}", bx + 30, by, 0, c_white, c_shadow]

          bar_max = 52
          bar_fill = (val * bar_max / 160.0).round.clamp(2, bar_max)
          panel.fill_rect(bx + 62, by + 5, bar_max, 6, Color.new(35, 45, 60))
          overlay.fill_rect(bx + 62, by + 5, bar_fill, 6, st[2])
        end
      else
        textpos << ["STAT BASE", 254, 160, 0, c_cyan, c_shadow]
        textpos << ["Cattura per rivelare", 378, 200, 2, c_silver, c_shadow]
        textpos << ["le statistiche!", 378, 222, 2, c_silver, c_shadow]
      end

      # Info extra
      other = HabitatRadarData.count_other_maps_for_species(cur[:id], @map_id)
      if other == 0
        textpos << ["Esclusivo!", 378, 256, 2, c_gold, c_shadow]
      else
        textpos << ["In altre #{other} mappe", 378, 256, 2, c_cyan, c_shadow]
      end

      is_target = ($PokemonGlobal && $PokemonGlobal.radar_tracked_species == cur[:id])
      gps_text = is_target ? "C: Rimuovi GPS" : "C: Imposta GPS"
      gps_col = is_target ? c_red : c_green
      textpos << [gps_text, 378, 278, 2, gps_col, c_shadow]

      # GPS tracker attivo
      if $PokemonGlobal && $PokemonGlobal.radar_tracked_species
        t_name = "?"
        begin; t_name = GameData::Species.get($PokemonGlobal.radar_tracked_species).name; rescue; end
        t_short = t_name.length > 10 ? "#{t_name[0...9]}.." : t_name
        textpos << ["GPS: #{t_short}", 378, 300, 2, c_gold, c_shadow]
      end

    else
      @sprites["battler"].visible = false
      @current_battler_species = nil
      textpos << ["Nessun dettaglio", 378, 80, 2, c_silver, c_shadow]
      draw_panel(panel, 248, 156, 260, 164, Color.new(18, 24, 38), Color.new(50, 75, 110))
      textpos << ["Seleziona un percorso", 378, 230, 2, c_silver, c_shadow]
    end

    # =====================================================================
    # 5. FOOTER (y=324, h=22)
    # =====================================================================
    draw_panel(panel, 4, 324, 504, 22, Color.new(16, 22, 34), Color.new(55, 80, 115))
    textpos << ["Scorri  << >> Mappe  C Azioni  Esc Esci", 256, 326, 2, c_white, c_shadow]

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
        pbSEPlay("GUI naming tab") rescue nil
        pbOpenSearchPrompt
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
    list = @scene.instance_variable_get(:@pokemon_list)
    sel = @scene.instance_variable_get(:@selected_index)

    choices = []
    cmd_track   = -1
    cmd_routes  = -1
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
        pbMessage(_INTL("{1} impostato come Target!
Riceverai un allarme quando apparira in battaglia!", cur_item[:name]))
      end
      @scene.refresh_ui

    elsif choice == cmd_routes && cur_item
      pbShowAllRoutesForSpecies(cur_item[:id], cur_item[:name])

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
