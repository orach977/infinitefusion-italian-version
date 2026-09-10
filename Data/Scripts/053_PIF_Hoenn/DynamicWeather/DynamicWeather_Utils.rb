# frozen_string_literal: true


def isRaining?()
  return isWeatherRain? || isWeatherStorm?
end

def isWeatherRain?()
  if $game_screen && $game_screen.weather_type
    weather_data = GameData::Weather.try_get($game_screen.weather_type)
    return true if weather_data && weather_data.category == :Rain
  end
  return false if !$game_weather || !$game_map
  return $game_weather.get_map_weather_type($game_map.map_id) == :Rain || $game_weather.get_map_weather_type($game_map.map_id) == :HeavyRain
end

def isWeatherSunny?()
  if $game_screen && $game_screen.weather_type
    weather_data = GameData::Weather.try_get($game_screen.weather_type)
    return true if weather_data && weather_data.category == :Sunny
  end
  return false if !$game_weather || !$game_map
  return $game_weather.get_map_weather_type($game_map.map_id) == :Sunny || $game_weather.get_map_weather_type($game_map.map_id) == :HarshSun
end

def isWeatherStorm?()
  if $game_screen && $game_screen.weather_type
    weather_data = GameData::Weather.try_get($game_screen.weather_type)
    return true if weather_data && weather_data.category == :Storm
  end
  return false if !$game_weather || !$game_map
  return $game_weather.get_map_weather_type($game_map.map_id) == :Storm
end

def isWeatherWind?()
  if $game_screen && $game_screen.weather_type
    weather_data = GameData::Weather.try_get($game_screen.weather_type)
    return true if weather_data && weather_data.category == :Wind
  end
  return false if !$game_weather || !$game_map
  return $game_weather.get_map_weather_type($game_map.map_id) == :Wind || $game_weather.get_map_weather_type($game_map.map_id) == :StrongWinds
end

def isWeatherFog?()
  if $game_screen && $game_screen.weather_type
    weather_data = GameData::Weather.try_get($game_screen.weather_type)
    return true if weather_data && weather_data.category == :Fog
  end
  return false if !$game_weather || !$game_map
  return $game_weather.get_map_weather_type($game_map.map_id) == :Fog
end

def isWeatherSnow?()
  if $game_screen && $game_screen.weather_type
    weather_data = GameData::Weather.try_get($game_screen.weather_type)
    return true if weather_data && weather_data.category == :Snow
  end
  return false if !$game_weather || !$game_map
  return $game_weather.get_map_weather_type($game_map.map_id) == :Snow
end


def changeCurrentWeather(weatherType,intensity)
  return nil if !$game_map
  new_map_id = $game_map.map_id
  mapMetadata = GameData::MapMetadata.try_get(new_map_id)
  return nil if mapMetadata.nil?
  return nil if !mapMetadata.outdoor_map
  if $game_weather
    $game_weather.set_map_weather($game_map.map_id,weatherType,intensity)
    $game_weather.update_overworld_weather($game_map.map_id)
  elsif $game_screen
    $game_screen.weather(weatherType,intensity,5)
  end
end