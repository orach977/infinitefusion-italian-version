class DoublePreviewScreen
  attr_reader :sprite_left
  attr_reader :sprite_right

  SELECT_ARROW_X_LEFT   = 100
  SELECT_ARROW_X_RIGHT  = 350
  SELECT_ARROW_X_CANCEL = 236

  SELECT_ARROW_Y_SELECT = 0
  SELECT_ARROW_Y_CANCEL = 295
  ARROW_GRAPHICS_PATH   = "Graphics/Pictures/Fusion/selHand"
  CANCEL_BUTTON_PATH   = "Graphics/Pictures/Fusion/previewScreen_Cancel"
  BACKGROUND_PATH       = "Graphics/Pictures/shadeFull_"
  EVO_BUTTON_PATH       = "Graphics/Pictures/Fusion/previewScreen_evolution"
  EVO_BUTTON_X          = 272
  EVO_BUTTON_Y          = 4

  ICON_EVO_HAS_CUSTOM    = "Graphics/Pictures/Fusion/evoCustom"
  ICON_EVO_HAS_NO_CUSTOM = "Graphics/Pictures/Fusion/evoNoCustom"
  ICON_EVO_FULL_CUSTOM   = "Graphics/Pictures/Fusion/evoCustom_full"
  CANCEL_BUTTON_X        = 128
  CANCEL_BUTTON_Y        = 315

  def initialize(species_left, species_right)
    @species_left      = species_left
    @species_right     = species_right

    @typewindows       = []
    @picture1          = nil
    @picture2          = nil
    @draw_types        = nil
    @draw_level        = nil
    @draw_sprite_info  = nil
    @selected          = 0
    @last_post         = 0
    @sprites           = {}
    @sprite_right      = nil
    @selected_sprite   = nil
    @fusion_dex_left   = nil
    @fusion_dex_right  = nil
    @level             = 1

    initializeBackground
    initializeSelectArrow
    initializeCancelButton
    initializeEvolutionsButton
    hideAllEvoIcons
    initializeBottomHintBar
  end

  def getBackgroundPicture
    return BACKGROUND_PATH
  end

  def getSelection
    selected = startSelection
    @sprites["cancel"].visible = false if @sprites["cancel"]

    if selected == 0
      @selected_sprite = @sprite_left
      return @species_left
    end
    if selected == 1
      @selected_sprite = @sprite_right
      return @species_right
    end
    return -1
  end

  def get_selected_sprite
    return @selected_sprite
  end

  def startSelection
    loop do
      Graphics.update
      Input.update
      updateSelection
      if Input.trigger?(Input::USE)
        return @selected
      end
      if Input.trigger?(Input::BACK)
        return -1
      end
      if (Input.trigger?(Input::ACTION) || Input.trigger?(Input::JUMPUP)) && @selected >= 0
        res = pbShowDetailedPage(@selected)
        return @selected if res == :choose
      end
    end
  end

  def updateSelection
    currentSelected = @selected
    updateSelectionIndex
    if @selected != currentSelected
      updateSelectionGraphics
    end
  end

  def updateSelectionIndex
    @up_hold_frames ||= 0

    if @selected == -1
      @up_hold_frames = 0
      if Input.trigger?(Input::UP)
        @selected = @last_post
      end
    else
      if Input.trigger?(Input::LEFT)
        @selected = 0
      elsif Input.trigger?(Input::RIGHT)
        @selected = 1
      elsif Input.trigger?(Input::DOWN)
        @last_post = @selected
        @selected = -1
      end

      if Input.press?(Input::UP) && @selected > -1
        @up_hold_frames += 1
        showAllEvoIcons if @up_hold_frames >= 6
      else
        @up_hold_frames = 0
        hideAllEvoIcons
      end
    end
  end

  def hideAllEvoIcons
    @sprites["evo"].visible = true if @sprites["evo"]
    @evo_icons_visible = false
    @sprites.each do |key, sprite|
      sprite.visible = false if key.start_with?("evo_icon_")
    end
  end

  def showAllEvoIcons
    @sprites["evo"].visible = false if @sprites["evo"]
    unless @evo_icons_visible
      pbSEPlay("GUI storage show party panel") rescue nil
      @evo_icons_visible = true
    end
    @sprites.each do |key, sprite|
      sprite.visible = true if key.start_with?("evo_icon_")
    end
  end

  def updateSelectionGraphics
    if @selected == 0
      @sprites["arrow"].x = SELECT_ARROW_X_LEFT
      @sprites["arrow"].y = SELECT_ARROW_Y_SELECT
    elsif @selected == 1
      @sprites["arrow"].x = SELECT_ARROW_X_RIGHT
      @sprites["arrow"].y = SELECT_ARROW_Y_SELECT
    else
      @sprites["arrow"].x = SELECT_ARROW_X_CANCEL
      @sprites["arrow"].y = SELECT_ARROW_Y_CANCEL
    end
    pbUpdateSpriteHash(@sprites)
  end

  def draw_window(dexNumber, level, x, y, isShiny=false, bodyShiny = false, headShiny=false, window_position=0)
    body_pokemon = getBodyID(dexNumber)
    head_pokemon = getHeadID(dexNumber, body_pokemon)

    @level = level
    if window_position == 0
      @fusion_dex_left = dexNumber
    else
      @fusion_dex_right = dexNumber
    end

    spriteLoader = BattleSpriteLoader.new
    bitmap = GameData::Species.front_sprite_bitmap(dexNumber)
    bitmap.shiftAllColors(dexNumber, bodyShiny, headShiny)
    bitmap.scale_bitmap(Settings::FRONTSPRITE_SCALE)
    pif_sprite = spriteLoader.obtain_fusion_pif_sprite(head_pokemon, body_pokemon)

    if window_position == 0
      @sprite_left = pif_sprite
    else
      @sprite_right = pif_sprite
    end

    @viewport_evo = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport_evo.z = 100001
    drawEvolutionIcons(dexNumber, @viewport_evo, x + 16, y + 12, window_position)

    previewwindow = PictureWindow.new(bitmap)
    previewwindow.x = x
    previewwindow.y = y
    previewwindow.z = 99999

    drawFusionInformation(dexNumber, level, x)

    # Nota: Rimosso il filtro di oscuramento/silhouette (pbSetColor)
    # in modo che lo sprite dell'anteprima di fusione sia sempre chiaramente visibile!
    return previewwindow
  end

  def drawEvolutionIcons(dexNumber, viewport, x, y, window_position)
    current_species = GameData::Species.get(dexNumber)
    if current_species.is_fusion
      body_num = getBodyID(current_species.id_number)
      head_num = getHeadID(current_species.id_number, body_num)
      body_chain = GameData::Species.get(body_num).get_ordered_family_species
      head_chain = GameData::Species.get(head_num).get_ordered_family_species

      ordered_species = []
      seen = {}
      body_chain.each do |body_sp|
        head_chain.each do |head_sp|
          body_dex = getDexNumberForSpecies(body_sp)
          head_dex = getDexNumberForSpecies(head_sp)
          fused_id = getFusedPokemonIdFromDexNum(body_dex, head_dex)
          next if seen[fused_id]
          next unless GameData::Species.get(fused_id)
          seen[fused_id] = true
          ordered_species << fused_id
        end
      end
    else
      ordered_species = current_species.get_ordered_family_species
    end
    current_species_index = ordered_species.index(current_species.species) || 0

    parsed_species = []
    evolution_customs = []
    ordered_species.each do |species|
      next if parsed_species.include?(species)
      parsed_species << species
      evolution_customs << customSpriteExistsSpecies(species)
    end

    return if evolution_customs.empty?

    icon_width = 16
    icon_spacing = 4
    max_per_row = 10
    row_height = icon_width + 4

    rows = evolution_customs.each_slice(max_per_row).to_a
    rows.each_with_index do |row_customs, row_index|
      start_x = x + icon_spacing
      row_y = y + (row_index * row_height)
      row_customs.each_with_index do |has_custom, col_index|
        global_index = (row_index * max_per_row) + col_index
        icon_path = has_custom ? ICON_EVO_HAS_CUSTOM : ICON_EVO_HAS_NO_CUSTOM
        icon_path += "_selected" if global_index == current_species_index
        icon_bitmap = AnimatedBitmap.new(icon_path).bitmap
        icon_sprite = Sprite.new(viewport)
        icon_sprite.bitmap = icon_bitmap
        icon_sprite.x = start_x + (col_index * (icon_width + icon_spacing))
        icon_sprite.y = row_y
        icon_sprite.z = 10000
        @sprites["evo_icon_#{window_position}_#{global_index}"] = icon_sprite
      end
    end
  end

  def drawFusionInformation(fusedDexNum, level, x = 0)
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 100002
    @typewindows << viewport
    @typewindows << drawPokemonType(fusedDexNum, viewport, x + 31, 226) if @draw_types

    body_id = getBodyID(fusedDexNum)
    head_id = getHeadID(fusedDexNum, body_id)
    head_sp = GameData::Species.get(head_id)
    body_sp = GameData::Species.get(body_id)
    fused_sp = GameData::Species.get(fusedDexNum)

    hasCustom = customSpriteExists(body_id, head_id)
    bst = (fused_sp && fused_sp.base_stats) ? fused_sp.base_stats.values.sum : 0

    overlay = BitmapSprite.new(Graphics.width, Graphics.height, viewport).bitmap
    pbSetNarrowFont(overlay)

    label_base = Color.new(248, 248, 248)
    label_shadow = Color.new(40, 40, 50)
    center_x = x + 96
    textpos = []

    # 1. In cima (y = 4..24): Nome della fusione e badge Custom/Autogen
    name_text = fused_sp ? fused_sp.real_name : _INTL("Fusione")
    textpos << [name_text, center_x, 4, 2, Color.new(255, 255, 255), label_shadow]

    if hasCustom
      textpos << [_INTL("★ Custom Sprite"), center_x, 20, 2, Color.new(255, 215, 40), Color.new(120, 80, 0)]
    else
      textpos << [_INTL("Autogenerato"), center_x, 20, 2, Color.new(180, 185, 195), Color.new(50, 50, 60)]
    end

    # 2. Sotto la preview (y = 256..296): Livello, BST, Abilità, Hint
    bst_color = (bst >= 500) ? Color.new(100, 245, 120) : Color.new(255, 220, 80)
    textpos << [sprintf("Lv. %d", level), x + 24, 256, 0, label_base, label_shadow] if @draw_level
    textpos << [sprintf("BST: %d", bst), x + 168, 256, 1, bst_color, label_shadow]

    if fused_sp && fused_sp.abilities
      abil_names = fused_sp.abilities.map { |a| GameData::Ability.get(a).name rescue nil }.compact.uniq
      if abil_names.length > 0
        textpos << [sprintf("Abil: %s", abil_names.first(2).join("/")), center_x, 274, 2, Color.new(210, 220, 230), label_shadow]
      end
    end

    textpos << [_INTL("[Z: Scheda Dettagli]"), center_x, 292, 2, Color.new(100, 220, 255), Color.new(20, 50, 90)]

    pbDrawTextPositions(overlay, textpos)
    drawSpriteInfoIcons(getPokemon(fusedDexNum), viewport) if @draw_sprite_info
  end

  def pbShowDetailedPage(selected_index)
    dexNumber = (selected_index == 0) ? @fusion_dex_left : @fusion_dex_right
    return :back if !dexNumber

    pbPlayDecisionSE rescue nil

    detail_viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    detail_viewport.z = 200000

    overlay_sprite = BitmapSprite.new(Graphics.width, Graphics.height, detail_viewport)
    overlay = overlay_sprite.bitmap
    pbSetNarrowFont(overlay)

    body_id = getBodyID(dexNumber)
    head_id = getHeadID(dexNumber, body_id)
    head_sp = GameData::Species.get(head_id)
    body_sp = GameData::Species.get(body_id)
    fused_sp = GameData::Species.get(dexNumber)
    return :back if !fused_sp || !head_sp || !body_sp

    hasCustom = customSpriteExists(body_id, head_id)
    bst = fused_sp.base_stats ? fused_sp.base_stats.values.sum : 0

    # Sfondo principale scuro con bordo illuminato
    overlay.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(12, 16, 26, 245))
    overlay.fill_rect(8, 8, Graphics.width - 16, Graphics.height - 16, Color.new(22, 28, 44, 250))
    overlay.fill_rect(8, 8, Graphics.width - 16, 2, Color.new(70, 130, 230))
    overlay.fill_rect(8, Graphics.height - 10, Graphics.width - 16, 2, Color.new(70, 130, 230))
    overlay.fill_rect(8, 8, 2, Graphics.height - 16, Color.new(70, 130, 230))
    overlay.fill_rect(Graphics.width - 10, 8, 2, Graphics.height - 16, Color.new(70, 130, 230))

    label_base = Color.new(245, 245, 245)
    label_shadow = Color.new(35, 40, 50)
    textpos = [
      [_INTL("SCHEDA COMPLETA DELLA FUSIONE"), Graphics.width / 2, 14, 2, Color.new(255, 215, 60), Color.new(100, 70, 0)],
      [fused_sp.real_name, 120, 36, 2, Color.new(255, 255, 255), label_shadow]
    ]

    # Sprite della fusione nel riquadro sinistro
    sprite_bitmap = GameData::Species.front_sprite_bitmap(dexNumber)
    if sprite_bitmap
      sprite_bitmap.scale_bitmap(Settings::FRONTSPRITE_SCALE) rescue nil
      sw = sprite_bitmap.width
      sh = sprite_bitmap.height
      sx = 120 - (sw / 2)
      sy = 54 + (140 - sh) / 2
      overlay.fill_rect(24, 54, 192, 140, Color.new(15, 20, 32))
      overlay.blt(sx, sy, sprite_bitmap.bitmap, Rect.new(0, 0, sw, sh))
    end

    # Tipi sotto lo sprite
    typebitmap = AnimatedBitmap.new("Graphics/Pictures/types")
    t1_num = GameData::Type.get(fused_sp.type1).id_number
    t2_num = GameData::Type.get(fused_sp.type2).id_number
    t1_rect = Rect.new(0, t1_num * 28, 64, 28)
    t2_rect = Rect.new(0, t2_num * 28, 64, 28)
    if fused_sp.type1 == fused_sp.type2
      overlay.blt(88, 198, typebitmap.bitmap, t1_rect)
    else
      overlay.blt(55, 198, typebitmap.bitmap, t1_rect)
      overlay.blt(121, 198, typebitmap.bitmap, t2_rect)
    end
    typebitmap.dispose

    # Badge Custom / Autogen
    if hasCustom
      textpos << [_INTL("★ Custom Sprite dedicato!"), 120, 230, 2, Color.new(255, 215, 40), Color.new(120, 80, 0)]
    else
      textpos << [_INTL("Sprite Autogenerato"), 120, 230, 2, Color.new(180, 185, 195), label_shadow]
    end

    # Dettaglio componenti Testa e Corpo
    overlay.fill_rect(24, 250, 192, 76, Color.new(28, 36, 56))
    textpos << [_INTL("Testa: {1}", head_sp.real_name), 30, 254, 0, Color.new(120, 210, 255), label_shadow]
    head_t_str = GameData::Type.get(head_sp.type1).name
    head_t_str += "/" + GameData::Type.get(head_sp.type2).name if head_sp.type1 != head_sp.type2
    textpos << [sprintf("(Tipo: %s)", head_t_str), 30, 270, 0, Color.new(180, 190, 205), label_shadow]

    textpos << [_INTL("Corpo: {1}", body_sp.real_name), 30, 288, 0, Color.new(255, 160, 120), label_shadow]
    body_t_str = GameData::Type.get(body_sp.type1).name
    body_t_str += "/" + GameData::Type.get(body_sp.type2).name if body_sp.type1 != body_sp.type2
    textpos << [sprintf("(Tipo: %s)", body_t_str), 30, 304, 0, Color.new(180, 190, 205), label_shadow]

    # PANNELLO DESTRO: Statistiche Base
    overlay.fill_rect(228, 36, 260, 162, Color.new(28, 36, 56))
    bst_col = (bst >= 500) ? Color.new(100, 245, 120) : Color.new(255, 220, 80)
    textpos << [sprintf("STATISTICHE BASE (BST: %d)", bst), 358, 42, 2, bst_col, label_shadow]

    stats_info = [
      [:HP, _INTL("PS"), fused_sp.base_stats[:HP] || 0],
      [:ATTACK, _INTL("Attacco"), fused_sp.base_stats[:ATTACK] || 0],
      [:DEFENSE, _INTL("Difesa"), fused_sp.base_stats[:DEFENSE] || 0],
      [:SPECIAL_ATTACK, _INTL("Att. Sp."), fused_sp.base_stats[:SPECIAL_ATTACK] || 0],
      [:SPECIAL_DEFENSE, _INTL("Dif. Sp."), fused_sp.base_stats[:SPECIAL_DEFENSE] || 0],
      [:SPEED, _INTL("Velocità"), fused_sp.base_stats[:SPEED] || 0]
    ]

    stats_info.each_with_index do |st, idx|
      sy = 62 + (idx * 22)
      textpos << [st[1], 236, sy, 0, label_base, label_shadow]
      textpos << [sprintf("%3d", st[2]), 310, sy, 1, label_base, label_shadow]

      # Disegna barra grafica per la statistica
      bar_x = 318
      bar_y = sy + 4
      bar_w = 160
      bar_h = 10
      bar_fill = [[(st[2] * bar_w / 180.0).round, bar_w].min, 2].max
      overlay.fill_rect(bar_x, bar_y, bar_w, bar_h, Color.new(15, 20, 30))
      fill_col = if st[2] >= 110
                   Color.new(80, 230, 110)
                 elsif st[2] >= 80
                   Color.new(245, 215, 60)
                 elsif st[2] >= 50
                   Color.new(255, 150, 40)
                 else
                   Color.new(240, 80, 80)
                 end
      overlay.fill_rect(bar_x + 1, bar_y + 1, bar_fill - 2, bar_h - 2, fill_col)
    end

    # PANNELLO DESTRO: Abilità Possibili
    overlay.fill_rect(228, 204, 260, 122, Color.new(28, 36, 56))
    textpos << [_INTL("ABILITÀ POSSIBILI"), 358, 208, 2, Color.new(120, 220, 255), label_shadow]

    if fused_sp && fused_sp.abilities
      abil_list = fused_sp.abilities.map { |a| GameData::Ability.get(a) rescue nil }.compact.uniq
      abil_y = 230
      abil_list.first(3).each do |ab|
        textpos << [ab.name, 236, abil_y, 0, Color.new(255, 225, 100), label_shadow]
        desc = ab.description rescue ""
        drawTextEx(overlay, 236, abil_y + 16, 244, 2, desc, Color.new(200, 205, 215), label_shadow)
        abil_y += 30
      end
    end

    # Barra Azioni in basso
    overlay.fill_rect(8, 334, Graphics.width - 16, 38, Color.new(18, 24, 38))
    textpos << [_INTL("[C / Invio]: Scegli questa fusione    |    [X / Z]: Torna alla selezione"), Graphics.width / 2, 344, 2, Color.new(120, 230, 255), label_shadow]

    pbDrawTextPositions(overlay, textpos)

    # Event loop per la visualizzazione della pagina
    result = :back
    loop do
      Graphics.update
      Input.update
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE rescue nil
        result = :choose
        break
      elsif Input.trigger?(Input::BACK) || Input.trigger?(Input::ACTION) || Input.trigger?(Input::JUMPUP)
        pbPlayCancelSE rescue nil
        result = :back
        break
      end
    end

    overlay_sprite.dispose
    detail_viewport.dispose
    return result
  end

  def initializeSelectArrow
    @sprites["arrow"] = IconSprite.new(0, 0, @viewport)
    @sprites["arrow"].setBitmap(ARROW_GRAPHICS_PATH)
    @sprites["arrow"].x = SELECT_ARROW_X_LEFT
    @sprites["arrow"].y = SELECT_ARROW_Y_SELECT
    @sprites["arrow"].z = 100001
  end

  def initializeEvolutionsButton
    @sprites["evo"] = IconSprite.new(0, 0, @viewport)
    @sprites["evo"].setBitmap(EVO_BUTTON_PATH)
    @sprites["evo"].x = EVO_BUTTON_X
    @sprites["evo"].y = EVO_BUTTON_Y
    @sprites["evo"].z = 100000
  end

  def initializeCancelButton
    @sprites["cancel"] = IconSprite.new(0, 0, @viewport)
    @sprites["cancel"].setBitmap(CANCEL_BUTTON_PATH)
    @sprites["cancel"].x = CANCEL_BUTTON_X
    @sprites["cancel"].y = CANCEL_BUTTON_Y
    @sprites["cancel"].z = 100000
  end

  def initializeBackground
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    @sprites["background"].setBitmap(getBackgroundPicture)
    @sprites["background"].x = 0
    @sprites["background"].y = 0
    @sprites["background"].z = 99999
  end

  def initializeBottomHintBar
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 100003
    @typewindows << viewport
    overlay = BitmapSprite.new(Graphics.width, Graphics.height, viewport).bitmap
    pbSetNarrowFont(overlay)
    textpos = [
      [_INTL("[C / Invio: Scegli]   [Z / Shift: Scheda Dettagli]   [X: Annulla]"), Graphics.width / 2, 362, 2, Color.new(225, 235, 245), Color.new(30, 40, 60)]
    ]
    pbDrawTextPositions(overlay, textpos)
  end

  def drawFusionPreviewText(viewport, text, x, y)
    label_base_color = Color.new(248, 248, 248)
    label_shadow_color = Color.new(104, 104, 104)
    overlay = BitmapSprite.new(Graphics.width, Graphics.height, viewport).bitmap
    textpos = [[text, x, y, 0, label_base_color, label_shadow_color]]
    pbDrawTextPositions(overlay, textpos)
  end

  def drawSpriteInfoIcons(fusedPokemon, viewport)
    # Placeholder per icone alt sprite
  end

  def dispose
    @picture1.dispose if @picture1
    @picture2.dispose if @picture2
    for typeWindow in @typewindows
      typeWindow.dispose if typeWindow
    end
    pbDisposeSpriteHash(@sprites)
  end

  def drawPokemonType(pokemon_id, viewport, x_pos = 192, y_pos = 264)
    width = 66
    viewport.z = 1000001
    overlay = BitmapSprite.new(Graphics.width, Graphics.height, viewport).bitmap

    pokemon = GameData::Species.get(pokemon_id)
    typebitmap = AnimatedBitmap.new("Graphics/Pictures/types")
    type1_number = GameData::Type.get(pokemon.type1).id_number
    type2_number = GameData::Type.get(pokemon.type2).id_number
    type1rect = Rect.new(0, type1_number * 28, 64, 28)
    type2rect = Rect.new(0, type2_number * 28, 64, 28)
    if pokemon.type1 == pokemon.type2
      overlay.blt(x_pos + (width / 2), y_pos, typebitmap.bitmap, type1rect)
    else
      overlay.blt(x_pos, y_pos, typebitmap.bitmap, type1rect)
      overlay.blt(x_pos + width, y_pos, typebitmap.bitmap, type2rect)
    end
    typebitmap.dispose
    return viewport
  end
end
