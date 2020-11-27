$map = []

Point = Struct.new(:x, :y)
class Point
  def <=>(other)
    y == other.y ? x <=> other.x : y <=> other.y
  end
  
  def adjacent(point)
    point.x == x && (point.y - y).abs == 1 ||
      point.y == y && (point.x - x).abs == 1
  end

  def points_from
    surrounding = [Point.new(x, y - 1), Point.new(x - 1, y),
                   Point.new(x + 1, y), Point.new(x, y + 1)]
    surrounding.select { |p| $map[p.y][p.x] == '.' } # non-wall
  end    
end

def next_moves(starts)
  starts.each { |s| $map[s.y][s.x] = :explored }
  next_moves = starts.map { |s| s.points_from }.reduce(:+)
  next_moves.nil? ? [] : next_moves.uniq
end

def clear_map
  $map.each do |row|
    row.each.with_index do |cell, x|
      row[x] = '.' if cell == :explored
    end
  end
end

Character = Struct.new(:race, :position, :hp, :attack)
class Character
  def initialize(race:, position:, hp: 200, attack: 3)
    super(race, position, hp, attack)
  end

  def <=>(other)
    hp == other.hp ? position <=> other.position : hp <=> other.hp
  end
  
  def enemy
    race == :elf ? :goblin : :elf
  end

  def open
    position.points_from
  end

  def adjacent(point)
    position.adjacent(point)
  end

  def suffer_hit(damage = 3)
    self[:hp] -= damage
    if dead?
      $map[position.y][position.x] = '.'
    end
  end

  def move(new_position)
    $map[position.y][position.x] = '.'    
    self[:position].x = new_position.x
    self[:position].y = new_position.y
    $map[position.y][position.x] = self
  end

  def dead?
    hp < 1
  end

  def summary
    "#{to_s}(#{hp})"
  end

  def to_s
    race == :goblin ? 'G' : 'E'
  end

  def move_nearest(open)
    current = position.points_from
    reachable = current & open
    while current.any? && reachable.empty?
      current = next_moves(current)
      reachable = current & open
    end

    if reachable.empty?
      clear_map
      return
    end

    clear_map

    current = [reachable.sort!.first]
    
    adjacent = current.filter { |c| c.adjacent(position) }
    while adjacent.empty?
      current = next_moves(current)
      adjacent = current.filter { |c| c.adjacent(position) }
    end

    path = adjacent.sort!.first
    move(path)
    clear_map
  end
end

$characters = []

def find_characters(elvish_attack)
  $map.each.with_index do |row, y|
    row.each.with_index do |c, x|
      case c
      when 'G'
        goblin = Character.new(race: :goblin, position: Point.new(x, y))
        $map[y][x] = goblin
        $characters << goblin
      when 'E'
        elf = Character.new(race: :elf, position: Point.new(x, y), attack: elvish_attack)
        $map[y][x] = elf
        $characters << elf
      end
    end
  end
end

def reset
  $characters = []
  $rounds = 0
  $map = []
end

def run(f, elvish_attack = 3)
  reset
  File.readlines(f).each do |line|
    line.strip!
    $map << line.chars
  end
  find_characters(elvish_attack)
end

$rounds = 0
def round
  # sort by position in case they have moved
  $characters.sort! { |a, b| a.position <=> b.position }
    
  no_enemies_left = false
  $characters.each do |character|
    next if character.dead?
    enemies = $characters.select { |c| c.race == character.enemy && c.hp > 0 }
    no_enemies_left = enemies.empty?
    break if no_enemies_left

    adjacent = enemies.select { |e| e.adjacent(character.position) }
    if adjacent.empty?
      open_squares = enemies.map(&:open).reduce(:+).uniq.sort
      if open_squares.any?
        character.move_nearest(open_squares)
        adjacent = enemies.select { |e| e.adjacent(character.position) }
      end
    end

    adjacent.sort!.first.suffer_hit(character.attack) if adjacent.any?
  end

  killed = $characters.map { |c| c.dead? ? [ c.race ] : [] }.reduce(:+).uniq
  $characters.delete_if(&:dead?)
  $rounds += 1 if !no_enemies_left
  [ no_enemies_left ? :finished : :keep_fighting, killed ]
end

def show_map
  $map.each do |row|
    character_info = (row.filter { |e| e.instance_of?(Character) }).map(&:summary).join(", ")
    map_info = row.map { |e| e == :explored ? '*' : e.to_s }.join('')
    puts "#{map_info}\t#{character_info}"
  end
  puts
end
    
def battle(early_end = nil)
  battle_status = [ :keep_fighting, [] ]
  while battle_status[0] == :keep_fighting && !battle_status[1].include?(early_end)
    battle_status = round
  end
  battle_status[1].include? early_end
end

def score
  $characters.delete_if(&:dead?)
  $rounds * $characters.map(&:hp).reduce(:+)
end

def no_elvish_deaths(f)
  elvish_attack = 3
  elvish_deaths = true
  while elvish_deaths
    elvish_attack += 1
    run(f, elvish_attack)
    elvish_deaths = battle(:elf)
  end

  score
end
