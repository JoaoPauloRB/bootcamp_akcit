extends Node
## AudioManager autoload — handles background music and sound effects.
## Music crossfades between rooms, SFX uses a player pool for overlap.

# --- Music ---
var _music_player: AudioStreamPlayer
var _current_track: String = ""

# --- SFX Pool ---
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 4

# --- Caches ---
var _music_tracks: Dictionary = {}
var _sfx_cache: Dictionary = {}


func _ready() -> void:
	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -6.0
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)

	# Create SFX player pool
	for i: int in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = -3.0
		add_child(player)
		_sfx_players.append(player)

	# Preload music tracks
	_music_tracks = {
		"vila": preload("res://assets/shared/audio/music/xDeviruchi - Take some rest and eat some food!.wav"),
		"floresta": preload("res://assets/shared/audio/music/xDeviruchi - And The Journey Begins .wav"),
		"dungeon": preload("res://assets/shared/audio/music/xDeviruchi - Mysterious Dungeon.wav"),
	}

	# Preload SFX
	_sfx_cache = {
		"attack": preload("res://assets/shared/audio/sfx/kenney-rpg/knifeSlice.ogg"),
		"hit": preload("res://assets/shared/audio/sfx/kenney-rpg/chop.ogg"),
		"enemy_death": preload("res://assets/shared/audio/sfx/kenney-rpg/cloth3.ogg"),
		"player_hurt": preload("res://assets/shared/audio/sfx/kenney-rpg/metalClick.ogg"),
		"pickup": preload("res://assets/shared/audio/sfx/kenney-rpg/handleCoins.ogg"),
	}


## Play a music track by name. Does nothing if already playing.
func play_music(track_name: String) -> void:
	if track_name == _current_track:
		return
	_current_track = track_name
	var stream: AudioStream = _music_tracks.get(track_name)
	if stream:
		_music_player.stream = stream
		_music_player.play()


## Stop the current music track.
func stop_music() -> void:
	_music_player.stop()
	_current_track = ""


## Play a sound effect by name using the SFX pool.
func play_sfx(sfx_name: String) -> void:
	var stream: AudioStream = _sfx_cache.get(sfx_name)
	if not stream:
		return
	# Find an available player
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	# All busy — reuse first player
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


## Loop music when track ends (WAV files don't loop by default).
func _on_music_finished() -> void:
	_music_player.play()
