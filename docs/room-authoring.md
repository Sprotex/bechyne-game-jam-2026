# Room authoring

Each room scene attaches `room.gd` and declares its `room_title`. The level reads that title for the HUD. Add a `RoomExit` instance for every traversable door; exits are independent, so multiple exits can use the same wall and lead to different rooms.

To add a door, drag `scenes/room_exit.tscn` into the room, set its wall side and position over the threshold, then set its destination scene path and destination arrival ID. Add a `Marker2D` below the room's `Arrivals` node with that ID as its name. The reverse door is a separate exit in the destination room. Destination scene paths avoid cyclic `PackedScene` references while keeping the room links directly editable in the Inspector.

The hall staircase remains decorative and has no destination until a room is designed for it. Do not assign a route to it yet.

Room boundaries and door openings create physical wall collisions. The player position marks the feet; the sprite and circular collision shape sit above that point. Horizontal speed is 260 and the adjustable vertical speed ratio defaults to 0.55 for the high angle room art. Exit triggers sit just inside their door openings, and arrival markers sit on the walkable side of the corresponding threshold.

## Persistent pickups and flags

Instance `scenes/persistent_pickup.tscn` for a collectible, give it a stable unique `item_id`, and set the displayed `item_label`. Interacting sets that ID in the level's flag store and hides the pickup. Other gameplay code can check `Level.has_flag("key.front_door")` to gate a door or dialog. Flags are saved to `user://game_progress.cfg`, so collected items remain gone after room changes and game restarts. To reset local progress during development, delete that file from the Godot user data directory.
