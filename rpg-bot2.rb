require 'cinch'

$party = []
$monsters = []
$started = false
$initiative = []
$turn = nil

class Character
  attr_accessor :hp, :max_hp, :str, :agi

  def initialize(lvl, hp, str, agi)
    @hp = hp*lvl
    @max_hp = @hp
    @str = str*lvl
    @agi = agi*lvl
  end

  def attack
    rand(@agi) > 0 ? rand(@str) + 1 : :miss
  end
end

class Imp < Character
  def initialize(lvl=1)
    super(lvl, 5, 3, 3)
  end

  def to_s
    "Imp"
  end
end

class Fighter < Character
  def initialize(lvl=1)
    super(lvl, 10, 5, 3)
  end

  def to_s
    "Fighter"
  end
end


def list_party
  $party.collect{|e| e[:nick] + " (#{e[:char]})"}.join ", "
end

def list_monsters
  $monsters.join ", "
end

def list_initiative
  $initiative.collect{|i| i == :monsters ? i : $party[i][:nick]}.join ", "
end

def spawn_monsters
  $party.size.times{$monsters << Imp.new}
end

def random_initiative
  $initiative = ((0..$party.size - 1).to_a << :monsters).sort_by{rand}
end

def do_monsters_turn(m)
  m.channel.msg "It's the monsters turn."
  next_turn(m)
end

def next_turn(m)
  $turn = $turn + 1
  $turn = 0 if $turn > $party.size

  if $initiative[$turn] == :monsters
    do_monsters_turn(m)
  else
    m.channel.msg $party[$initiative[$turn]][:nick] + ": It's your turn!"
  end
end

def end_game
  $monsters = []
  $turn = nil
  $initiative = []
  $started = false
end

class Join
  include Cinch::Plugin
  match "join"

  def execute(m)
    nick = m.user.nick
    unless $party.collect{|e| e[:nick]}.include? nick
      $party << {char: Fighter.new, nick: nick}
      m.channel.msg "Party: " + list_party
    end
  end
end

class Start
  include Cinch::Plugin
  match "start"

  def execute(m)
    if $party.size > 0 && !$started
      spawn_monsters
      m.channel.msg "Wild monsters appear: " + list_monsters
      random_initiative
      m.channel.msg "Turn order will be: " + list_initiative, false
      $turn = -1
      $started = true
      next_turn(m)
    end
  end
end

class Attack
  include Cinch::Plugin
  match "attack"

  def execute(m)
    player = $party[$initiative[$turn]]
    nick = player[:nick]
    target = 0
    monster = $monsters[target]

    if $started && nick == m.user.nick
      if (dmg = player[:char].attack) != :miss
        m.channel.msg nick + " hits the #{monster} for #{dmg} damage."
        $monsters[target].hp = monster.hp - dmg
        if $monsters[target].hp < 1
          m.channel.msg "The #{monster} perishes."
          $monsters.delete_at target 
          m.channel.msg $monsters.inspect
        end
      else
        m.channel.msg nick + " misses the #{monster}."
      end

      if $monsters.size == 0
        end_game
      else
        next_turn(m)
      end
    end
  end
end

Cinch::Bot.new do
  configure do |c|
    c.nick = "rpb#{rand(1000)}"
    c.server = "irc.freenode.org"
    c.channels = ["##the_basement"]
    c.plugins.plugins = [Join, Start, Attack]
  end
end.start
