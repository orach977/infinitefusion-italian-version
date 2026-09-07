#===============================================================================
# Base class for all three menu classes below
#===============================================================================
class BattleMenuBase
  attr_accessor :x
  attr_accessor :y
  attr_reader   :z
  attr_reader   :visible
  attr_reader   :color
  attr_reader   :index
  attr_reader   :mode
  # NOTE: Button width is half the width of the graphic containing them all.
  BUTTON_HEIGHT = 46
  TEXT_BASE_COLOR   = PokeBattle_SceneConstants::MESSAGE_BASE_COLOR
  TEXT_SHADOW_COLOR = PokeBattle_SceneConstants::MESSAGE_SHADOW_COLOR

  def initialize(viewport=nil)
    @x          = 0
    @y          = 0
    @z          = 0
    @visible    = false
    @color      = Color.new(0,0,0,0)
    @index      = 0
    @mode       = 0
    @disposed   = false
    @sprites    = {}
    @visibility = {}
  end

  def dispose
    return if disposed?
    pbDisposeSpriteHash(@sprites)
    @disposed = true
  end

  def disposed?; return @disposed; end

  def z=(value)
    @z = value
    for i in @sprites
      i[1].z = value if !i[1].disposed?
    end
  end

  def visible=(value)
    @visible = value
    for i in @sprites
      i[1].visible = (value && @visibility[i[0]]) if !i[1].disposed?
    end
  end

  def color=(value)
    @color = value
    for i in @sprites
      i[1].color = value if !i[1].disposed?
    end
  end

  def index=(value)
    oldValue = @index
    @index = value
    @cmdWindow.index = @index if @cmdWindow
    refresh if @index!=oldValue
  end

  def mode=(value)
    oldValue = @mode
    @mode = value
    refresh if @mode!=oldValue
  end

  def addSprite(key,sprite)
    @sprites[key]    = sprite
    @visibility[key] = true
  end

  def setIndexAndMode(index,mode)
    oldIndex = @index
    oldMode  = @mode
    @index = index
    @mode  = mode
    @cmdWindow.index = @index if @cmdWindow
    refresh if @index!=oldIndex || @mode!=oldMode
  end

  def refresh; end

  def update
    pbUpdateSpriteHash(@sprites)
  end
end



#===============================================================================
# Command menu (Fight/Pokémon/Bag/Run)
#===============================================================================
class CommandMenuDisplay < BattleMenuBase
  # If true, displays graphics from Graphics/Pictures/Battle/overlay_command.png
  #     and Graphics/Pictures/Battle/cursor_command.png.
  # If false, just displays text and the command window over the graphic
  #     Graphics/Pictures/Battle/overlay_message.png. You will need to edit def
  #     pbShowWindow to make the graphic appear while the command menu is being
  #     displayed.
  USE_GRAPHICS = true
  # Lists of which button graphics to use in different situations/types of battle.
  MODES = [
     [0,2,1,3],   # 0 = Regular battle
     [0,2,1,9],   # 1 = Regular battle with "Cancel" instead of "Run"
     [0,2,1,4],   # 2 = Regular battle with "Call" instead of "Run"
     [5,7,6,3],   # 3 = Safari Zone
     [0,8,1,3]    # 4 = Bug Catching Contest
  ]


  def initialize(viewport,z,baseColor=nil,shadowColor=nil)
    super(viewport)
    self.x = 0
    self.y = Graphics.height-96
    # Create message box (shows "What will X do?")
    @msgBox = Window_UnformattedTextPokemon.newWithSize("",
       self.x+16,self.y+2,220,Graphics.height-self.y,viewport)

    @baseColor   = baseColor || PokeBattle_SceneConstants::MESSAGE_BASE_COLOR
    @shadowColor = shadowColor || PokeBattle_SceneConstants::MESSAGE_SHADOW_COLOR
    if isDarkMode
      @baseColor, @shadowColor = @shadowColor, @baseColor
    end

    @msgBox.baseColor   = @baseColor
    @msgBox.shadowColor = @shadowColor

    if isDarkMode
      @msgBox.baseColor, @msgBox.shadowColor = @msgBox.shadowColor, @msgBox.baseColor
    end

    @msgBox.windowskin  = nil
    addSprite("msgBox",@msgBox)
    if USE_GRAPHICS
      # Create background graphic
      background = IconSprite.new(self.x,self.y,viewport)
      background.setBitmap("Graphics/Pictures/Battle/overlay_command")
      addSprite("background",background)

      commands_img_path = "Graphics/Pictures/Battle/cursor_command"
      commands_img_path += "_dark" if isDarkMode
      # Create bitmaps
      @buttonBitmap = AnimatedBitmap.new(commands_img_path)
      # Create action buttons
      @buttons = Array.new(4) do |i|   # 4 command options, therefore 4 buttons
        button = SpriteWrapper.new(viewport)
        button.bitmap = @buttonBitmap.bitmap
        button.x      = self.x+Graphics.width-260
        button.x      += (((i%2)==0) ? 0 : @buttonBitmap.width/2-4)
        button.y      = self.y+6
        button.y      += (((i/2)==0) ? 0 : BUTTON_HEIGHT-4)
        button.src_rect.width  = @buttonBitmap.width/2
        button.src_rect.height = BUTTON_HEIGHT
        addSprite("button_#{i}",button)
        next button
      end
    else
      # Create command window (shows Fight/Bag/Pokémon/Run)
      @cmdWindow = Window_CommandPokemon.newWithSize([],
         self.x+Graphics.width-240,self.y,240,Graphics.height-self.y,viewport)
      @cmdWindow.columns       = 2
      @cmdWindow.columnSpacing = 4
      @cmdWindow.ignore_input  = true
      addSprite("cmdWindow",@cmdWindow)
    end
    self.z = z
    refresh
  end

  def dispose
    super
    @buttonBitmap.dispose if @buttonBitmap
  end

  def z=(value)
    super
    @msgBox.z    += 1
    @cmdWindow.z += 1 if @cmdWindow
  end

  def setTexts(value)
    @msgBox.text = value[0]
    return if USE_GRAPHICS
    commands = []
    for i in 1..4
      commands.push(value[i]) if value[i] && value[i]!=nil
    end
    @cmdWindow.commands = commands
  end

  def refreshButtons
    return if !USE_GRAPHICS
    for i in 0...@buttons.length
      button = @buttons[i]
      button.src_rect.x = (i==@index) ? @buttonBitmap.width/2 : 0
      button.src_rect.y = MODES[@mode][i]*BUTTON_HEIGHT
      button.z          = self.z + ((i==@index) ? 3 : 2)
    end
  end

  def refresh
    @msgBox.refresh
    @cmdWindow.refresh if @cmdWindow
    refreshButtons
  end
end



#===============================================================================
# Fight menu (choose a move)
#===============================================================================
class FightMenuDisplay < BattleMenuBase
  attr_reader :battler
  attr_reader :shiftMode

  # If true, displays graphics from Graphics/Pictures/Battle/overlay_fight.png
  #     and Graphics/Pictures/Battle/cursor_fight.png.
  # If false, just displays text and the command window over the graphic
  #     Graphics/Pictures/Battle/overlay_message.png. You will need to edit def
  #     pbShowWindow to make the graphic appear while the command menu is being
  #     displayed.
  USE_GRAPHICS     = true
  TYPE_ICON_HEIGHT = 28
  # Colori PP dinamici per tema moderno Dark Glass
  PP_COLORS = [
     Color.new(255, 80, 80),   Color.new(90, 20, 20),    # Rosso, PP esauriti
     Color.new(255, 120, 40),  Color.new(110, 40, 10),   # Arancione, <= 1/4 PP
     Color.new(255, 215, 0),   Color.new(120, 90, 0),    # Giallo, <= 1/2 PP
     Color.new(100, 240, 150), Color.new(20, 80, 40)    # Verde lime, > 1/2 PP
  ]

  def initialize(viewport,z)
    super(viewport)
    self.x = 0
    self.y = Graphics.height-96
    @battler   = nil
    @shiftMode = 0
    # NOTE: @mode is for the display of the Mega Evolution button.
    #       0=don't show, 1=show unpressed, 2=show pressed
    if USE_GRAPHICS
      # Create bitmaps
      button_path = "Graphics/Pictures/Battle/cursor_fight"
      type_path = "Graphics/Pictures/types"
      category_path = "Graphics/Pictures/category"
      if isDarkMode
        button_path += "_dark"
      end
      @buttonBitmap   = AnimatedBitmap.new(button_path)
      @typeBitmap     = AnimatedBitmap.new(type_path)
      @categoryBitmap = AnimatedBitmap.new(category_path)

      @megaEvoBitmap = AnimatedBitmap.new("Graphics/Pictures/Battle/cursor_mega")
      @shiftBitmap   = AnimatedBitmap.new("Graphics/Pictures/Battle/cursor_shift")
      # Create background graphic
      background = IconSprite.new(0,Graphics.height-96,viewport)
      background.setBitmap("Graphics/Pictures/Battle/overlay_fight")
      addSprite("background",background)
      # Create move buttons
      @buttons = Array.new(Pokemon::MAX_MOVES) do |i|
        button = SpriteWrapper.new(viewport)
        button.bitmap = @buttonBitmap.bitmap
        button.x      = self.x+4
        button.x      += (((i%2)==0) ? 0 : @buttonBitmap.width/2-4)
        button.y      = self.y+6
        button.y      += (((i/2)==0) ? 0 : BUTTON_HEIGHT-4)
        button.src_rect.width  = @buttonBitmap.width/2
        button.src_rect.height = BUTTON_HEIGHT
        addSprite("button_#{i}",button)
        next button
      end
      # Create overlay for buttons (shows move names and pill badges)
      @pokemon_name_overlay = BitmapSprite.new(Graphics.width, Graphics.height-self.y, viewport)
      @pokemon_name_overlay.x = self.x
      @pokemon_name_overlay.y = self.y
      pbSetSystemFont(@pokemon_name_overlay.bitmap)
      @pokemon_name_overlay.bitmap.font.size = 22
      addSprite("overlay", @pokemon_name_overlay)
      # Create overlay for selected move's info (shows move's PP, POT, PREC, Eff pill)
      @infoOverlay = BitmapSprite.new(Graphics.width,Graphics.height-self.y,viewport)
      @infoOverlay.x = self.x
      @infoOverlay.y = self.y
      pbSetSystemFont(@infoOverlay.bitmap)
      @infoOverlay.bitmap.font.size = 24
      addSprite("infoOverlay",@infoOverlay)
      # Create type icon
      @typeIcon = SpriteWrapper.new(viewport)
      @typeIcon.bitmap = @typeBitmap.bitmap
      @typeIcon.x      = self.x+390
      @typeIcon.y      = self.y+10
      @typeIcon.src_rect.height = TYPE_ICON_HEIGHT
      addSprite("typeIcon",@typeIcon)
      # Create category icon (Fisico, Speciale, Stato)
      @categoryIcon = SpriteWrapper.new(viewport)
      @categoryIcon.bitmap = @categoryBitmap.bitmap
      @categoryIcon.x      = self.x+458
      @categoryIcon.y      = self.y+10
      @categoryIcon.src_rect.x = 10
      @categoryIcon.src_rect.width = 44
      @categoryIcon.src_rect.height = 28
      addSprite("categoryIcon",@categoryIcon)
      # Create Mega Evolution button
      @megaButton = SpriteWrapper.new(viewport)
      @megaButton.bitmap = @megaEvoBitmap.bitmap
      @megaButton.x      = self.x+120
      @megaButton.y      = self.y-@megaEvoBitmap.height/2
      @megaButton.src_rect.height = @megaEvoBitmap.height/2
      addSprite("megaButton",@megaButton)
      # Create Shift button
      @shiftButton = SpriteWrapper.new(viewport)
      @shiftButton.bitmap = @shiftBitmap.bitmap
      @shiftButton.x      = self.x+4
      @shiftButton.y      = self.y-@shiftBitmap.height
      addSprite("shiftButton",@shiftButton)
    else
      # Create message box (shows type and PP of selected move)
      @msgBox = Window_AdvancedTextPokemon.newWithSize("",
         self.x+320,self.y,Graphics.width-320,Graphics.height-self.y,viewport)
      @msgBox.baseColor   = TEXT_BASE_COLOR
      @msgBox.shadowColor = TEXT_SHADOW_COLOR
      pbSetNarrowFont(@msgBox.contents)
      addSprite("msgBox",@msgBox)
      # Create command window (shows moves)
      @cmdWindow = Window_CommandPokemon.newWithSize([],
         self.x,self.y,320,Graphics.height-self.y,viewport)
      @cmdWindow.columns       = 2
      @cmdWindow.columnSpacing = 4
      @cmdWindow.ignore_input  = true
      pbSetNarrowFont(@cmdWindow.contents)
      addSprite("cmdWindow",@cmdWindow)
    end
    self.z = z
  end

  def dispose
    super
    @buttonBitmap.dispose if @buttonBitmap
    @typeBitmap.dispose if @typeBitmap
    @categoryBitmap.dispose if @categoryBitmap
    @megaEvoBitmap.dispose if @megaEvoBitmap
    @shiftBitmap.dispose if @shiftBitmap
  end

  def z=(value)
    super
    @msgBox.z      += 1 if @msgBox
    @cmdWindow.z   += 2 if @cmdWindow
    @pokemon_name_overlay.z     += 5 if @pokemon_name_overlay
    @infoOverlay.z += 6 if @infoOverlay
    @typeIcon.z    += 1 if @typeIcon
    @categoryIcon.z += 1 if @categoryIcon
  end

  def battler=(value)
    @battler = value
    refresh
    refreshButtonNames
  end

  def shiftMode=(value)
    oldValue = @shiftMode
    @shiftMode = value
    refreshShiftButton if @shiftMode!=oldValue
  end

  # Helper per disegnare badge a pillola con angoli arrotondati e bordo sottile
  def drawPill(bitmap, px, py, pw, ph, bg_color, border_color=nil)
    return if !bitmap || !bg_color
    bitmap.fill_rect(px + 2, py, pw - 4, ph, bg_color)
    bitmap.fill_rect(px + 1, py + 1, pw - 2, ph - 2, bg_color)
    bitmap.fill_rect(px, py + 2, pw, ph - 4, bg_color)
    if border_color
      bitmap.fill_rect(px + 2, py, pw - 4, 1, border_color)
      bitmap.fill_rect(px + 2, py + ph - 1, pw - 4, 1, border_color)
      bitmap.fill_rect(px, py + 2, 1, ph - 4, border_color)
      bitmap.fill_rect(px + pw - 1, py + 2, 1, ph - 4, border_color)
      bitmap.fill_rect(px + 1, py + 1, 1, 1, border_color)
      bitmap.fill_rect(px + pw - 2, py + 1, 1, 1, border_color)
      bitmap.fill_rect(px + 1, py + ph - 2, 1, 1, border_color)
      bitmap.fill_rect(px + pw - 2, py + ph - 2, 1, 1, border_color)
    end
  end

  def getEffectivenessData(move)
    return nil if !move || !@battler || !@battler.battle
    opp = @battler.pbDirectOpposing(true)
    return nil if !opp
    if move.statusMove?
      return {
        :badge  => _INTL("--"),
        :full   => _INTL("Stato"),
        :tag    => _INTL("STATO"),
        :bg     => Color.new(26, 76, 112),
        :border => Color.new(38, 108, 160),
        :base   => Color.new(255, 255, 255),
        :shadow => Color.new(10, 30, 48)
      }
    end
    mod = move.pbCalcTypeMod(move.type, @battler, opp)
    if Effectiveness.ineffective?(mod)
      return {
        :badge  => _INTL("x0"),
        :full   => _INTL("Immune"),
        :tag    => _INTL("IMMUNE"),
        :bg     => Color.new(80, 90, 105),
        :border => Color.new(110, 122, 140),
        :base   => Color.new(255, 255, 255),
        :shadow => Color.new(25, 30, 36)
      }
    elsif Effectiveness.extremely_effective?(mod)
      return {
        :badge  => _INTL("x4"),
        :full   => _INTL("Super (x4)"),
        :tag    => _INTL("SUPER x4"),
        :bg     => Color.new(210, 165, 20),
        :border => Color.new(255, 215, 0),
        :base   => Color.new(255, 255, 255),
        :shadow => Color.new(70, 50, 5)
      }
    elsif Effectiveness.super_effective?(mod)
      return {
        :badge  => _INTL("x2"),
        :full   => _INTL("Super (x2)"),
        :tag    => _INTL("SUPER x2"),
        :bg     => Color.new(34, 160, 70),
        :border => Color.new(50, 200, 90),
        :base   => Color.new(255, 255, 255),
        :shadow => Color.new(10, 55, 22)
      }
    elsif Effectiveness.mostly_ineffective?(mod)
      return {
        :badge  => _INTL("x0.25"),
        :full   => _INTL("Poco x0.25"),
        :tag    => _INTL("POCO x0.25"),
        :bg     => Color.new(220, 50, 50),
        :border => Color.new(255, 90, 90),
        :base   => Color.new(255, 255, 255),
        :shadow => Color.new(65, 12, 12)
      }
    elsif Effectiveness.not_very_effective?(mod)
      return {
        :badge  => _INTL("x0.5"),
        :full   => _INTL("Poco x0.5"),
        :tag    => _INTL("POCO x0.5"),
        :bg     => Color.new(230, 95, 40),
        :border => Color.new(255, 140, 70),
        :base   => Color.new(255, 255, 255),
        :shadow => Color.new(70, 25, 10)
      }
    else
      return {
        :badge  => _INTL("x1"),
        :full   => _INTL("Efficace"),
        :tag    => _INTL("EFFIC."),
        :bg     => Color.new(35, 48, 70),
        :border => Color.new(55, 75, 105),
        :base   => Color.new(220, 230, 245),
        :shadow => Color.new(12, 18, 28)
      }
    end
  rescue
    return nil
  end

  def refreshButtonNames
    moves = (@battler) ? @battler.moves : []
    if !USE_GRAPHICS
      # Fill in command window
      commands = []
      for i in 0...[4, moves.length].max
        commands.push((moves[i]) ? moves[i].name : "-")
      end
      @cmdWindow.commands = commands
      return
    end
    # Draw move names and badges onto overlay
    @pokemon_name_overlay.bitmap.clear
    pbSetSystemFont(@pokemon_name_overlay.bitmap)
    textPos = []
    badgeTextPos = []

    @buttons.each_with_index do |button,i|
      next if !@visibility["button_#{i}"] || !moves[i]
      bx = button.x - self.x
      by = button.y - self.y
      name_x = bx + 16
      y = by + 6
      moveNameBase = Color.new(255, 255, 255)
      moveNameShadow = Color.new(12, 16, 26)

      textPos.push([moves[i].name, name_x, y, 0, moveNameBase, moveNameShadow])

      # Indicatore pillola efficacia a destra del pulsante mossa
      eff = getEffectivenessData(moves[i])
      if eff && eff[:badge]
        pw = (eff[:badge].length > 2) ? 42 : 36
        ph = 18
        px = bx + 188 - pw - 6
        py = by + 12
        drawPill(@pokemon_name_overlay.bitmap, px, py, pw, ph, eff[:bg], eff[:border])
        badgeTextPos.push([eff[:badge], px + (pw / 2), py - 2, 2, eff[:base], eff[:shadow]])
      end
    end

    @pokemon_name_overlay.bitmap.font.size = 22
    pbDrawTextPositions(@pokemon_name_overlay.bitmap, textPos) if textPos.length > 0

    @pokemon_name_overlay.bitmap.font.size = 16
    pbDrawTextPositions(@pokemon_name_overlay.bitmap, badgeTextPos) if badgeTextPos.length > 0
  end

  def refreshSelection
    moves = (@battler) ? @battler.moves : []
    if USE_GRAPHICS
      # Choose appropriate button graphics and z positions
      @buttons.each_with_index do |button,i|
        if !moves[i]
          @visibility["button_#{i}"] = false
          next
        end
        @visibility["button_#{i}"] = true
        button.src_rect.x = (i==@index) ? @buttonBitmap.width/2 : 0
        button.src_rect.y = GameData::Type.get(moves[i].type).id_number * BUTTON_HEIGHT
        button.z          = self.z + ((i==@index) ? 4 : 3)
      end
    end
    refreshMoveData(moves[@index])
  end

  def refreshMoveData(move)
    # Write PP and type of the selected move
    if !USE_GRAPHICS
      moveType = GameData::Type.get(move.type).name
      if move.total_pp<=0
        @msgBox.text = _INTL("PP: ---<br>TYPE/{1}",moveType)
      else
        @msgBox.text = _ISPRINTF("PP: {1: 2d}/{2: 2d}<br>TYPE/{3:s}",
           move.pp,move.total_pp,moveType)
      end
      return
    end
    @infoOverlay.bitmap.clear
    pbSetSystemFont(@infoOverlay.bitmap)
    if !move
      @visibility["typeIcon"] = false
      @visibility["categoryIcon"] = false if @categoryIcon
      return
    end
    @visibility["typeIcon"] = true
    type_number = GameData::Type.get(move.type).id_number
    @typeIcon.src_rect.y = type_number * TYPE_ICON_HEIGHT

    if @categoryIcon
      @visibility["categoryIcon"] = true
      @categoryIcon.src_rect.y = move.category * 28
    end

    # 1. POT & PREC (Row 2, y = 38)
    pwr_text = (move.baseDamage > 0) ? _INTL("POT: {1}", move.baseDamage) : _INTL("POT: ---")
    acc_text = (move.accuracy > 0) ? _INTL("PREC: {1}", move.accuracy) : _INTL("PREC: ---")
    stat_color = Color.new(225, 230, 242)
    stat_shadow = Color.new(12, 16, 26)

    @infoOverlay.bitmap.font.size = 15
    statsPos = [
      [pwr_text, 390, 38, 0, stat_color, stat_shadow],
      [acc_text, 506, 38, 1, stat_color, stat_shadow]
    ]
    pbDrawTextPositions(@infoOverlay.bitmap, statsPos)

    # 2. PP (Row 3, y = 60)
    pp_str = (move.total_pp > 0) ? _INTL("PP: {1}/{2}", move.pp, move.total_pp) : _INTL("PP: ---")
    if move.total_pp > 0
      ppFraction = [(4.0 * move.pp / move.total_pp).ceil, 3].min
      ppColorBase = PP_COLORS[ppFraction * 2]
      ppColorShadow = PP_COLORS[ppFraction * 2 + 1]
    else
      ppColorBase = PP_COLORS[0]
      ppColorShadow = PP_COLORS[1]
    end

    @infoOverlay.bitmap.font.size = 18
    ppPos = [
      [pp_str, 390, 60, 0, ppColorBase, ppColorShadow]
    ]
    pbDrawTextPositions(@infoOverlay.bitmap, ppPos)

    # 3. Pillola Efficacia in basso a destra (Row 3, y = 62)
    eff = getEffectivenessData(move)
    if eff && eff[:badge]
      pw = (eff[:badge].length > 2) ? 42 : 36
      ph = 20
      px = 506 - pw
      py = 62
      drawPill(@infoOverlay.bitmap, px, py, pw, ph, eff[:bg], eff[:border])
      @infoOverlay.bitmap.font.size = 15
      tagPos = [
        [eff[:badge], px + (pw / 2), py - 2, 2, eff[:base], eff[:shadow]]
      ]
      pbDrawTextPositions(@infoOverlay.bitmap, tagPos)
    end
  end

  def refreshMegaEvolutionButton
    return if !USE_GRAPHICS
    @megaButton.src_rect.y    = (@mode - 1) * @megaEvoBitmap.height / 2
    @megaButton.x             = self.x + ((@shiftMode > 0) ? 204 : 120)
    @megaButton.z             = self.z - 1
    @visibility["megaButton"] = (@mode > 0)
  end

  def refreshShiftButton
    return if !USE_GRAPHICS
    @shiftButton.src_rect.y    = (@shiftMode - 1) * @shiftBitmap.height
    @shiftButton.z             = self.z - 1
    @visibility["shiftButton"] = (@shiftMode > 0)
  end

  def refresh
    return if !@battler
    refreshSelection
    refreshMegaEvolutionButton
    refreshShiftButton
  end
end



#===============================================================================
# Target menu (choose a move's target)
# NOTE: Unlike the command and fight menus, this one doesn't have a textbox-only
#       version.
#===============================================================================
class TargetMenuDisplay < BattleMenuBase
  attr_accessor :mode

  # Lists of which button graphics to use in different situations/types of battle.
  MODES = [
     [0,2,1,3],   # 0 = Regular battle
     [0,2,1,9],   # 1 = Regular battle with "Cancel" instead of "Run"
     [0,2,1,4],   # 2 = Regular battle with "Call" instead of "Run"
     [5,7,6,3],   # 3 = Safari Zone
     [0,8,1,3]    # 4 = Bug Catching Contest
  ]
  CMD_BUTTON_WIDTH_SMALL = 170
  TEXT_BASE_COLOR   = Color.new(240,248,224)
  TEXT_SHADOW_COLOR = Color.new(64,64,64)

  def initialize(viewport,z,sideSizes)
    super(viewport)
    @sideSizes = sideSizes
    maxIndex = (@sideSizes[0]>@sideSizes[1]) ? (@sideSizes[0]-1)*2 : @sideSizes[1]*2-1
    @smallButtons = (@sideSizes.max>2)
    self.x = 0
    self.y = Graphics.height-96
    @texts = []
    # NOTE: @mode is for which buttons are shown as selected.
    #       0=select 1 button (@index), 1=select all buttons with text
    # Create bitmaps
    @buttonBitmap = AnimatedBitmap.new("Graphics/Pictures/Battle/cursor_target")
    # Create target buttons
    @buttons = Array.new(maxIndex+1) do |i|
      numButtons = @sideSizes[i%2]
      next if numButtons<=i/2
      # NOTE: Battler indexes go from left to right from the perspective of
      #       that side's trainer, so inc is different for each side for the
      #       same value of i/2.
      inc = ((i%2)==0) ? i/2 : numButtons-1-i/2
      button = SpriteWrapper.new(viewport)
      button.bitmap = @buttonBitmap.bitmap
      button.src_rect.width  = (@smallButtons) ? CMD_BUTTON_WIDTH_SMALL : @buttonBitmap.width/2
      button.src_rect.height = BUTTON_HEIGHT
      if @smallButtons
        button.x    = self.x+170-[0,82,166][numButtons-1]
      else
        button.x    = self.x+138-[0,116][numButtons-1]
      end
      button.x      += (button.src_rect.width-4)*inc
      button.y      = self.y+6
      button.y      += (BUTTON_HEIGHT-4)*((i+1)%2)
      addSprite("button_#{i}",button)
      next button
    end
    # Create overlay (shows target names)
    @pokemon_name_overlay = BitmapSprite.new(Graphics.width, Graphics.height-self.y, viewport)
    @pokemon_name_overlay.x = self.x
    @pokemon_name_overlay.y = self.y
    pbSetNarrowFont(@pokemon_name_overlay.bitmap)
    addSprite("overlay", @pokemon_name_overlay)
    self.z = z
    refresh
  end

  def dispose
    super
    @buttonBitmap.dispose if @buttonBitmap
  end

  def z=(value)
    super
    @pokemon_name_overlay.z += 5 if @pokemon_name_overlay
  end

  def setDetails(texts,mode)
    @texts = texts
    @mode  = mode
    refresh
  end

  def refreshButtons
    # Choose appropriate button graphics and z positions
    @buttons.each_with_index do |button,i|
      next if !button
      sel = false
      buttonType = 0
      if @texts[i]
        sel ||= (@mode==0 && i==@index)
        sel ||= (@mode==1)
        buttonType = ((i%2)==0) ? 1 : 2
      end
      buttonType = 2*buttonType + ((@smallButtons) ? 1 : 0)
      button.src_rect.x = (sel) ? @buttonBitmap.width/2 : 0
      button.src_rect.y = buttonType*BUTTON_HEIGHT
      button.z          = self.z + ((sel) ? 3 : 2)
    end
    # Draw target names onto overlay
    @pokemon_name_overlay.bitmap.clear
    textpos = []
    @buttons.each_with_index do |button,i|
      next if !button || nil_or_empty?(@texts[i])
      x = button.x-self.x+button.src_rect.width/2
      y = button.y-self.y+2
      textpos.push([@texts[i],x,y,2,TEXT_BASE_COLOR,TEXT_SHADOW_COLOR])
    end
    pbDrawTextPositions(@pokemon_name_overlay.bitmap, textpos)
  end

  def refresh
    refreshButtons
  end
end
