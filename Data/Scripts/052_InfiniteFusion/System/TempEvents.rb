class PokemonTemp
  attr_accessor :tempEvents
  attr_accessor :silhouetteDirection

  def tempEvents
    @tempEvents = {} if !@tempEvents
    return @tempEvents
  end

  def pbClearTempEvents()
    return if !@tempEvents || @tempEvents.empty?
    @tempEvents.keys.each { |map_id|
      map = $MapFactory.getMapNoAdd(map_id)
      @tempEvents[map_id].each { |event|
        $game_self_switches[[map_id, event.id, "A"]] = false
        $game_self_switches[[map_id, event.id, "B"]] = false
        $game_self_switches[[map_id, event.id, "C"]] = false
        $game_self_switches[[map_id, event.id, "D"]] = false

        map.events[event.id].erase if map.events[event.id]
      }
    }
    @tempEvents = {}
    @silhouetteDirection = nil
  end

  def createTempEvent(eventTemplateID, map_id, position = [0, 0],direction=nil, event_class = Game_Event)
    return unless $scene.is_a?(Scene_Map)
    template_map = $MapFactory.getMap(MAP_TEMPLATE_EVENTS,false)
    return unless template_map && template_map.events[eventTemplateID]
    template_event = template_map.events[eventTemplateID]
    key_id = ($game_map.events.keys.max || -1) + 1

    # Disarm any incompatible tripwire scripts in the template event in memory
    if template_event.event && template_event.event.pages
      template_event.event.pages.each do |page|
        if page.list && page.list.any? { |c| c.parameters && c.parameters[0].to_s.include?("OW encounters are not") }
          page.trigger = 0
          page.list = [RPG::EventCommand.new(0, 0, [])]
        end
      end
    end

    rpgEvent = template_event.event.dup
    rpgEvent.id = key_id

    # For Overworld Pokemon events or events containing incompatible scripts, ensure sanitized pages
    is_ow = defined?(OverworldPokemonEvent) && (event_class <= OverworldPokemonEvent rescue false)
    if rpgEvent.pages
      clean_pages = []
      rpgEvent.pages.each do |p|
        new_p = p.clone
        has_incompatible = new_p.list && new_p.list.any? { |c| c.parameters && c.parameters[0].to_s.include?("OW encounters are not") }
        if is_ow || has_incompatible
          new_p.trigger = 0
          new_p.list = [RPG::EventCommand.new(0, 0, [])]
        end
        clean_pages << new_p
      end
      rpgEvent.pages = clean_pages
    end

    gameEvent = event_class.new($game_map.map_id, rpgEvent, $game_map)

    gameEvent.moveto(position[0], position[1])
    gameEvent.direction = direction if direction

    yield gameEvent if block_given?

    registerTempEvent(map_id, gameEvent)

    $game_map.events[key_id] = gameEvent
    sprite = Sprite_Character.new(Spriteset_Map.viewport, $game_map.events[key_id])
    $scene.spritesets[$game_map.map_id] = Spriteset_Map.new($game_map) if $scene.spritesets[$game_map.map_id] == nil
    $scene.spritesets[$game_map.map_id].character_sprites.push(sprite)
    return gameEvent
  end

  def registerTempEvent(map, event)
    @tempEvents = {} if !@tempEvents
    mapEvents = @tempEvents.has_key?(map) ? @tempEvents[map] : []
    mapEvents.push(event)
    @tempEvents[map] = mapEvents
  end

end

